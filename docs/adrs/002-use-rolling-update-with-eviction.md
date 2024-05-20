---
status: accepted
date: 2024-05-17
deciders: Kamil Kołodziej, Radosław Szuma, Jakub Pisarek
informed: Fishjam Team, Cloud Team
---
# Change deployment strategy to eliminate downtime

## Context and Problem Statement

In the current situation when we do a deployment we are shuting down the server and every room with that.
This is an awful user experience. Another issue is the fact that any ongoing recordings are lost.

## Decision Drivers

* No downtime while deployment happens
* 0 lost recordings during deployment

## Considered Options

* Rolling update with eviction
* Active room migration

## Decision Outcome

Chosen option: "Rolling update with eviction", because
while second option sounds great, we acknowledge that solution is not trivial and we want to fix downtimes ASAP. First solution is a good starting point to remove existing problems and allow us to move forward.

### Consequences

Every new deployment will need to trigger fishjam process which will handle the shutdown.
What that effectively means is that we are leaving the responsibility of triggering deployment to external orchestration tool (what is usually the case) but we handle the process inside the app.

External process will trigger fishjam shutdown process by a SIGTERM.
This is gonna mark fishjam as one that no longer accepts new rooms.
Once every room is closed and all of the recordings are computed we are going to shutdown that instance of fishjam.

This is applicable one by one for every instance in cluster, although it may take some time to deployment a new version and we may have 2 different versions on the cluster at the same time, we are accepting that tradeoff.
We must also consider `force` option to deploy a version no matter the state of fishjam (which may result in downtime).

## Pros and Cons of the Options

### Rolling update with eviction

1. External orchestrator process triggers new deployment
2. Starts new instance of fishjam with new version
3. One of the fishjam instances receives SIGTERM
4. Fishjam shutdown process start
5. We mark that fishjam as one that no longer allows to create new rooms
6. Wait till the last room is closed and all recordings are completed
7. Once process is completed we shutdown the instance
8. (Possibly) Repeat for rest of the remaining instances

* Good, because we will eliminate downtimes with deployments
* Good, because we won't lose any recordings
* Good, because we trap the SIGTERM and handle shutdown gracefully
* Bad, because deployment process may take some time (effectively as long as the longest conversation/stream)
* Bad, because we may end up with different versions on cluster at the same time

###  Active room migration

This solution wasn't researched much so we supposed the flow should be like that:

1. External orchestrator process triggers new deployment
2. Starts new instance of fishjam with new version
3. One of the old fishjam instances receives SIGTERM
4. We mark that fishjam as one that no longer allows to create new rooms
5. Fishjam starts migrating rooms to new instance
6. Somehow handles the recordings (?)
7. Once peers/rooms/streams are migrated, app is gonna shutdown
8. (Possibly) Repeat for rest of the remaining instances

* Good, because we will eliminate downtimes with deployments
* Good, because we won't lose any recordings
* Good, because it happens fast, we don't have to wait for rooms to close/streams to end
* Good, because we will have 2 different versions on cluster for a short amount of time
* Bad, because we don't have a clue how to handle the active peer migration to new instance right now
* Bad, because we don't know how to handle the meetings with recording enabled during the migration

## More Information

This decision is heavily dependent on the Cloud Team and may be changed soon to meet their requirements.