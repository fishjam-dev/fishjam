---
status: proposed
date: 17-05-2024
deciders: Kamil Kołodziej, Radosław Szuma, Jakub Pisarek
informed: Fishjam Team, Cloud Team
---
# Change release strategy to eliminate downtimes

## Context and Problem Statement

In the current situation when we do a release we are shuting down the server and every room with that.
This is an awful user experience. Another issue is the fact that any ongoing recordings are lost.

## Decision Drivers

* N o downtime while release happens
* 0 lost recordings during release

## Considered Options

* Rolling update with eviction
* Active room migration

## Decision Outcome

Chosen option: "Rolling update with eviction", because
while second option sounds great, we acknowledge that solution is not trivial and we want to fix downtimes ASAP. First solution is a good starting point to remove existing problems and allow us to move forward.

### Consequences

Every new release will need to trigger fishjam process which will handle the shutdown. What that effectively means is that we are leaving the responsibility of triggering release to external orchestration tool (what is usually the case) and to monitor if the application exited correctly.

External process will trigger fishjam shutdown process which is gonna mark application as one that no longer accepts the connections (new rooms etc.). Once every room is closed and all of the recordings are computed we are going to mark fishjam as ready to shutdown. This application instance should also be effectively removed from any external load balancing (k8s etc.) while it should still allow erlang clustering. Orchestrator process should query the fishjam till it's ready to shutdown and sends sigterm signal.

This is applicable one by one for every instance in cluster, although it may take some time to release a new version and we may have 2 different versions on the cluster at the same time, we are accepting that tradeoff. We may consider `force` option to release a version no matter the state of fishjam (which may result in downtime).

## Pros and Cons of the Options

### Rolling update with eviction

1. External orchestrator process triggers new release
2. Starts new instance of fishjam with new version
3. Fishjam shutdown process start
4. Stop receiving traffic to that instance
5. Wait till the last room is closed and all recordings are completed
6. Finish fishjam shutdown process - ready for sigterm
7. External orchestrator process kills fishjam instance
8. Repeat for rest of the remaining instances

* Good, because we will eliminate downtimes with releases
* Good, because we won't lose any recordings
* Neutral, because we require some external work from the orchestrator
* Bad, because release process may take some time (effectively as long as the longest conversation/stream)
* Bad, because we may end up with different versions on cluster at the same time

###  Active room migration

This solution wasn't researched much so we supposed the flow should be like that:

1. External orchestrator process triggers new release
2. Starts new instance of fishjam with new version
3. Fishjam starts migrating rooms to new instance
4. Somehow handles the recordings (?)
5. Once peers/rooms/streams are migrated app is ready for sigterm
6. External orchestrator process kills fishjam instance
7. Repeat for rest of the remaining instances

* Good, because we will eliminate downtimes with releases
* Good, because we won't lose any recordings
* Good, because it happens fast, we don't have to wait for rooms to close/streams to end
* Good, because we will have 2 different versions on cluster for a small amount of time
* Neutral, because we require some external work from the orchestrator
* Bad, because we don't have a clue how to handle the active peer migration to new instance right now
* Bad, because we don't know how to handle the meetings with recording enabled during the migration

## More Information

This is decision which is heavily dependent on the Cloud Team and may be change soon to meet their requirements.