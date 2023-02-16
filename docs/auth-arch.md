# Authentication architecture

**Glossary:**

- **CL** - client
- **BE** - business logic (backend)
- **JMS** - Jellyfish Media Server

## Approaches and connection with signaling architecture

Authentication might be a big factor when deciding on signaling architecture (see the other document). We need to consider 2 situations:

- **CL** connect directly do **JMS**,
- **CL** connect to **BE** which forwards signaling messages to **JMS**.

Let's start with the first approach.

### Direct connection between **CL** and **JMS**

Let's assume client wants to join some multimedia room and is already authenticated (from the bussines logic perspective, e.g. he is logged in to his account).
Also, **JMS** and **BE** share common secret (more about that later).
Scenario:

1) **CL** sends request to join the multimedia room to **BE**.
2) **BE** recieves the request and sends `add_peer` request to **JMS**.
3) **JMS** sends back created `peer_id`.
4) **BE** uses received `peer_id`, id of the **JMS** instance to create JWT token with that is signed with the secret (or the **JMS** creates the token in the previous step).
The token can also contain permissions (which may differ between "normal" client and administrator).
5) **BE** responds to **CL** with the token.
6) **CL** can now open WebSocket connection with **JMS** using the token to authorize. **JMS** (thanks to informations included in the token)
can tell who opened the connection and that it was intended for this instance of **JMS**.

Problems:

- who creates the token? (more on that later),
- the token can expire (this doesn's seem like a problem, when the token is used only to open WebSocker connection, but user possibly needs to implement logic to refresh the token).

### Using **BE** as a middleman

The same assumptions and first 3 steps as in the previous example:

4) **BE** responds to **CL** that it was authorized and that it can send signaling messages to **BE**.

Problems:

- in current implementation of `membrane_rtc_engine`, endpoint should be created after signaling connection was established. In previous example it was obvious:
WebSocekt connection is established, endpoint is created. Here some kind of special message will be necessary to communicate the begining of signaling connection. Also, we need
to think if we wont to use the token to tag the signaling messages (seems unnecessary), or simply `peer_id`, harder to manage permissions
(more of a signaling architecture problems, but worth noting).
- **BE** doesn't need to pass the token to **CL** (has to respond to in anyway to start signaling messages flow), but also have to take care of matching incoming messages with `peer_id`s.

## Who should create tokens?

### **BE**

If **BE** (server SDK) is responsible for creating tokens, then it has to know the secret that will be used to signing. It also needs `peer_id`, which can be obtained from **JMS**. That takes care of **CL** authorization, we also need to authorize **BE** - **JMS** connection. One possible solution to that is to use the very same secret to create tokens that will be used by **BE**. So **BE** will generate tokens and then, instead of sending them to client, will use it itself (which may seem wierd, but we came to conclusion that the approach is alright).

This approach only makes sense when using direct signaling, otherwise tokens are not necessary at all (except for **BE** - **JMS** connection).

### **JMS**

In this approach **JMS** creates the tokens (when using `add_peer`, token is send in the response), so user only needs to pass it to the **CL**.
You also might need to pass expected token presmissions to **JMS**.
Despite that, we still need a way to authenticate **BE** - **JMS** connection. Possible solutions:

- create JWT on **BE** side anyway (in such case you might as well use the first approach in order to not split logic responsible for token generation between Server SDK and Jellyfish),
- create JWT (or some other token type) once and use it in configuration (makes it easier to change **BE** permissions, if that's ever necessary, but the token never expires, I'm not surewhether that's a problem, also **BE** doesn't need to know the secret).

In both situations effort from the user comes to passing the token to **CL** (in direct signaling, otherwise no need to do anything except for creating the signalling connection).
