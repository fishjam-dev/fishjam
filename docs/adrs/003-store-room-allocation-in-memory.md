---
status: accepted
date: 2024-05-21
deciders: Kamil Kołodziej, Jakub Pisarek, Radosław Szuma
consulted: Michał Śledź
informed: Fishjam Team
---
# Route incoming traffic within the cluster without a need to provide room_id

## Context and Problem Statement

In the current architecture after we create a room in cluster we return on which instance (Jellyfish host) it was created.
This means that Jellyfish client needs to make request to only that specific instance.
Which effectively leads to the situation where client may need to keep mapping between room_id and jellyfish host.

We would like to hide information about internal architecture of the cluster and the exact JF hosts as well as make it easier for clients so they can use only cluster endpoint.

## Decision Drivers

* Cluster architecture should be an internal information
* `room_id` should be a sufficient information to route the requests

## Considered Options

* Store room allocation across the cluster using in-memory ETS
* Store room allocation across the cluster using database
* Leave it as it is and update the SKDs

## Decision Outcome

Chosen option: Store room allocation across the cluster using in-memory ETS.

### Consequences

- Routing within the cluster will take some of the responsibility from the client.
- This responsibility is moved to the internal part of the Fishjam.
- We may encounter some issues with data not being propagated quick enough or some message missing and will need to handle those scenarios.
- We need to add some observability tools/metrics to allow us detect any issue within the cluster.
- When it comes to the websocket we would prefer to forward it to the correct node instead of returning exact ws address or forward traffic.

We want to try it first with the data stored in ETS, because since our tool is an open source one, we don't want to enforce users to add database.
If this solution turns out not feasible, we will move towards using some external database or reiterate on ours research.

## Pros and Cons of the Options

### Store room allocation across the cluster using in-memory ETS

This option assumes that every node will keep track of the room allocation across the cluster in ETS.
The exact implementation may be different but the general idea is to publish to other nodes rooms on the local node.
Based on that factor it doesn't matter which node will receive the request we can guide it to the correct node.

* Good, because we drop the requirement for client to make request to specific instance
* Good, because it's a step towards the deployment without downtime
* Good, because we are in control of routing inside the cluster and internals do not leak out
* Bad, because if the data is eventually consistent and if we make 2 requests very quick (create room, add peer) second one can fail.
    This is because second request may land in a node which don't have information about that room yet.


### Store room allocation across the cluster using database

This option is identical to the previous one but the data is stored in some database not in ETS,
instead of asking the cache nodes could ask database where data is consistent.

* Good, because we drop the requirement for client to make request to specific instance
* Good, because it's a step towards the deployment without downtime
* Good, because we are in control of routing inside the cluster and internals do not leak out
* Good, because we eliminate the problem with the state where data is not yet propagated to the other nodes
* Bad, because we are adding requirement of having database if someone wants to use clustering


### Leave it as it is and update the SKDs

Last considered option is to leave the API as it is right now, but edit SDKs to allow connection to different nodes.

* Neutral, because this is going to hide the problem not to completely solve it
* Bad, because we are exposing the internal cluster architecture to the client/SDK
* Bad, because when we are going to deploy the SDKs needs to dynamically update available nodes (so some discover API)

## More Information

In those materials you can find a little bit more about the implementation details (especially in Jira).

(Slack thread)[https://swmansion.slack.com/archives/C05EDRWEXBR/p1715867445702489?thread_ts=1715766038.930809&cid=C05EDRWEXBR]
(Jira epic)[https://membraneframework.atlassian.net/browse/RTC-540]