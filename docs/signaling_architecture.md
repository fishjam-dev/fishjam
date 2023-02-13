# Signaling architecture

**Glossary:**

- **CL** - client
- **BE** - business logic (backend)
- **JMS** - Jellyfish Media Server

## Approaches

Currently we consider three approaches to signaling implementation:

- direct connection between **CL** and **JMS** bypassing **BE**
- using **BE** as a middleman to pass signaling messages
- ability to use either of options above, but providing some default implementation (i.e provide default implementation of direct signaling, but
let the user to replace it with his own implementation using the other approach)

### Direct connection

**CL** must be able to open connection to the **JMS** (e.g. WebSocket). For that it requires **JMS** address and some form of authentication.

**Example:**

1) **CL** sends request to **BE** to join some room (meeting, webinar).
2) **BE** generates secret and sends request to **JMS** (*add_peer*).
3) **JMS** responds positively.
4) **BE** responds to client with generated secret.
5) **CL** opens WebSocket connection to **JMS**, flow of signaling messages begin.

**JMS** can diferentiate between different clients by the opened WebSocket connection so it knows who is the sender of incoming Media Events and knows who is the recipent of generated Media Events.

**Advantages:**

- Easier option, the user doesn't have to do much more than pass the address and some secret (authentication token) to the client, client SDK handles the rest.
- Both **CL** and **JMS** can tell when signaling connection broke. That prevents situation when signaling connection between **CL** and **BE** was broken, but **BE** did not
notified **JMS** of such occurence, is that case media is still flowing with no signaling (when new peer joins, tracks are not renegotiated, etc.).
- 

**Disadvantages:**

- Client has to participate in the authentication process (so they propably need to be authenticated by **BE** and then authenticated again to open connection to **JMS**).
- Some events can get desynchronized. Imagine scenerio where **JMS** sent notification to **BE** that recording begun (it is **BE**'s responibility to propagate this information
to peers, so they can e.g. show some icon indicator). At the same moment, media and signaling connections borke for some reason, so for a brief moment (until **JMS** passes that information to **BE** and **BE** passes it to **CL**) **CL** might think that their screen is being recorded, even though that is not the case (situation in this example can be prevented, but I hope you get the gist).
- 

### Using **BE** as a middleman

Client SDK generates signaling messages, but requires the user to implement logic that handles forwarding them to **JMS**, using **BE** in described scenario.

**Exmaple:**

1) **CL** sends request to **BE** to join some room (meeting, webinar).
2) **BE** sends request to **JMS** (*add_peer*).
3) **JMS** responds positively.
4) **BE** responds to client positively.
5) **CL** starts generating signaling messages which are forwarded to **JMS** by **BE**.

In that case we need a way to identify the sender of signaling messages, we thought of 2 approaches:

- make **BE** open WebSocket connection to **JMS** for every client (here seems like a very bad idea, makes a bit more sense in the mixed approach described later)
- tag every signaling message (Media Event) with some form of identification, e.g. `peer_id`, requires only one WebSocket connection between **BE** and **JMS**

**Advantages:**

- easy to implement (from our, Jellyfish developers, perspective)
- **CL** does not require additional connection and authentication, everything is handled by **BE**.
- 

**Disadvantages:**

- harder to implement by the user, much more error prone
- encourages the user to implement logic that relies on content of Media Events (at least while it's JSON) which they should treat as a black box.
- 

### Mixed approach

By default, direct connection approach is used, but the use can swap the implementation to his own.
We assume that only one approach is used (there cannot be a situation when some peers are using direct signaling, and some signaling forwarded by **BE** at the same time).

Now the problem with identifying signaling messages becomes much more apparent.
If Media Events are individually tagged, when using direct approach there's some redundancy (**JMS** doesn't need the "tag", it can tell who is who by the WebSocket connection),
but the tags are necessary when using **BE** as a middleman. Obviously, we can handle each situation, but that makes the implementation much more complicated.

On the other hand, when tags are not used, there's everything alright with direct connection, but, again, situation with **BE** used as a broker has to handled differently 
(which makes it complicated) or **BE** has to open WebSocket connection for every client (meh -_-).

**Advantages:**

- More flexible.
- The best of both approaches.

**Disadvantages**

- More complicated to implement.
- Introduces some redundancy (at least the ways to identify Media Events that we thought of).
