# Authentication architecture

**Glossary:**

- **CL** - client
- **BE** - business logic (backend) implemented by the user
- **FJ** - Fishjam

## Approaches and connection with signaling architecture

Authentication might be a big factor when deciding on signaling architecture (see the other document). We need to consider 2 situations:

- **CL** connect directly do **FJ**,
- **CL** connect to **BE** which forwards signaling messages to **FJ**.

Let's start with the first approach.

### Direct connection between **CL** and **FJ**

Let's assume **CL** wants to join some multimedia room and is already authenticated (from the bussines logic perspective, e.g. he is logged into his account).
Also, **FJ** and **BE** share common secret (more about that later).
Scenario:

1) **CL** sends request to join the multimedia room to **BE**.
2) **BE** recieves the request and sends `add_peer` request to **FJ**.
3) **FJ** sends back created `peer_id`.
4) **BE** uses received `peer_id` and id of the **FJ** instance to create JWT that is signed with the secret (or the **FJ** creates the token in the previous step).
The token can also contain permissions (which may differ between "normal" clients and administrators).
5) **BE** responds to **CL** with the token.
6) **CL** can now open WebSocket connection to **FJ** using the token to authorize themselves. **FJ** (thanks to informations included in the token)
can tell who opened the connection and that it was intended for this instance of **FJ**.

Problems:

- who creates the token? (more on that later),
- the token can expire (this doesn's seem like a problem, when the token is used only to open WebSocker connection, but user possibly needs to implement logic to refresh the token).

### Using **BE** as a middleman

**Note: direct signaling approach has been chosen, so this paragraph is not applicable anymore.**

The same assumptions and first 3 steps as in the previous example:

4) **BE** responds to **CL** that it was authorized and that it can send signaling messages to **BE**.

Problems:

- in current implementation of `membrane_rtc_engine`, endpoint should be created after signaling connection was established. In previous example it was obvious:
WebSocekt connection is established, endpoint is created. Here some kind of special message will be necessary to communicate the begining of signaling connection. Also, we need
to think if we want to use the token to tag the signaling messages (seems unnecessary), or simply `peer_id`, it's harder to manage permissions
(more of a signaling architecture problems, but worth noting),
- **BE** doesn't need to pass the token to **CL** (has to respond to in anyway to start signaling messages flow), but have to take care of matching incoming messages with `peer_id`s.~

## Who should create tokens?

### **BE**

If **BE** (server SDK) is responsible for creating tokens, then it has to know the secret that will be used in signing JWT. It also needs `peer_id`, which can be obtained from **FJ**. That takes care of **CL** authorization, but we also need to authorize **BE** - **FJ** connection. One possible solution is to use the very same secret as before to create tokens that will be used by **BE**. So **BE** will generate token and then, instead of sending them to client, will use it itself (which may seem wierd, but we came to conclusion that the approach is alright).

This approach only makes sense when using direct signaling, otherwise tokens are not necessary at all (except for **BE** - **FJ** connection).

### **FJ**

In this approach **FJ** creates the tokens (when using `add_peer`, token is send in the response), so user only needs to pass it to the **CL**.
You also might need to pass expected token presmissions to **FJ**.
Despite that, we still need a way to authenticate **BE** - **FJ** connection. Possible solutions:

- create JWT on **BE** side anyway (in such case you might as well use the first approach in order not to split logic responsible for token generation between Server SDK and Fishjam),
- create JWT (or some other token type) once and use it in configuration (makes it easier to change **BE** permissions, if that's ever necessary, but the token never expires, I'm not sure whether that's a problem, also **BE** doesn't need to know the secret).

No matter who generates the tokens, effort from the user comes to passing the token to **CL** (in direct signaling, otherwise no need to do anything except for creating the signalling connection).

## Consclusion

We will be using **FJ** to generate tokens, as it makes it easier to maintain (we don't need to implement token generation in all of our SDKs) and we keep all of the logic responsible for generation and validation together.
Also, **BE** authentication might not be very difficult: they may just share a common secret and use it directly to authenticate (e.g. via HTTP authorization request header), especially when **FJ** and **BE** are in the same internal
network, which will be a common case. Using **BE** to generate tokens could also make it harder to make modifications related to tokens (need to redeploy both **FJ** and **BE** in such case).
