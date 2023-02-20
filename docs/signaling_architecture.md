# Signaling architecture

**Glossary:**

- **CL** - client
- **BE** - business logic (backend) implemented by the user
- **JF** - Jellyfish

## Approaches

Currently we consider three approaches to the signaling implementation:

- direct connection between **CL** and **JF** bypassing **BE**,
- using **BE** as a middleman to pass signaling messages,
- ability to use either of the options above, but providing some default implementation (i.e provide default implementation of direct signaling, but
let the user replace it with his own implementation).

### Direct connection

**CL** must be able to open connection to **JF** (e.g. WebSocket). For that **CL** requires **JF** address and some form of authentication.

**Example:**

1) **CL** sends request to **BE** to join some room (meeting, webinar etc.).
2) **BE** sends request to **JF** (*add_peer*).
3) **JF** responds positively.
4) **BE** responds to client positively with generated token.
5) **CL** opens WebSocket connection to **JF**, flow of signaling messages begins.

**JF** can diferentiate between the clients by the opened WebSocket connection. It knows
who is the sender of incoming Media Events and where to send generated Media Events.

**Advantages:**

- Easier option, the user doesn't have to do much more than passing authentication token to **CL**, client SDK handles the rest.
- Both **CL** and **JF** can tell when signaling connection was broken. That prevents situation when signaling connection between **CL** and **BE** was broken, but **BE**
did not notify **JF** of such occurence, is that case media is still flowing with no signaling (when new peer joins, tracks are not renegotiated, etc.).

**Disadvantages:**

- **CL** has to participate in the authentication process (so they probably need to be
authenticated by **BE** and then authenticated again to open connection to **JF**).
- Some events can get desynchronized. Imagine scenerio where **JF** sent notification to
**BE** that recording has begun (it is **BE**'s responibility
to propagate this information to clients so they can show some icon indicator). At
the same time, media and signaling connections were broken for some reason.
For a brief moment (until **JF** passes that information to **BE** and **BE** passes
it to **CL**) **CL** might think that their screen is being recorded
even though that is not the case (situation in this example can be prevented, but I hope
you get the gist).

### Using **BE** as a middleman

Client SDK generates signaling messages, but requires the user to implement logic that handles forwarding them to **JF** (using **BE** in described scenario).

**Exmaple:**

1) **CL** sends request to **BE** to join some room (meeting, webinar etc.).
2) **BE** sends request to **JF** (*add_peer*).
3) **JF** responds positively.
4) **BE** responds to client positively.
5) **CL** starts generating signaling messages which are forwarded to **JF** by **BE**.

In that case we need a way to identify the sender of signaling messages, we thought of 2 approaches (you'r welcome to suggest a better one):

- make **BE** open WebSocket connection to **JF** for every client (here seems like a very bad idea, makes a bit more sense in the mixed approach described later),
- tag every signaling message with something like `peer_id`, requires only one WebSocket connection between **BE** and **JF** (should SDK do this, or should it be the users responsibility?).

**Advantages:**

- Easy to implement (from our, Jellyfish developers, perspective).
- **CL** does not require additional connection and authentication, everything is handled by **BE**.

**Disadvantages:**

- Harder to implement by the user, much more error-prone (isn't that the point of Jellyfish to make it as simple as possible?).
- Encourages the user to implement logic that relies on content of signaling messages (at least while it's JSON) which they should treat as a "black box".

### Mixed approach

By default, direct connection approach is used, but the user can swap the implementation to his own.
We assume that only one approach is being used at once (there cannot be a situation when some peers are using direct signaling, and some signaling messages forwarded by **BE** at the same time), but that's a whole another thing to consider.

Now the problem with identifying signaling messages becomes much more apparent.

If signaling messages are individually tagged, when using direct connection approach there's some redundancy (**JF** doesn't need the "tag", it can tell who
is who by the WebSocket connection),
but the tags are necessary when using **BE** as a middleman. Obviously, we can handle each situation differently and not tag messages passed in
direct connection, but that makes the implementation much more complicated.

On the other hand, when tags are not used, there's everything alright with direct connection, but again, situation with **BE** used as a middleman has to be handled differently
(which makes it complicated) or **BE** has to open WebSocket connection for every client (consistent but meh).

**Advantages:**

- More flexible.
- The best of both worlds.

**Disadvantages:**

- More complicated to implement.
- Introduces some redundancy (at least the ways to identify signaling messages that we thought of).

## Conclusion

The approach that we are going to use is the **direct connection**, mostly because it's a lot easier for the user to implement (which outweights benefits like the flexibility of the other approach).
Also, the drawbacks seem not to be very severe: some of the information about the state of rooms and peers (like the fact that recording has begun) can be
kept and shared by **JF** via the signalling connection.
Mixed approach is not considered at the moment (as it brings some difficulties) but can be added in the future if there's need.
