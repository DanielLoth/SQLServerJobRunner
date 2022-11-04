create procedure JobRunner.GetRunnableStatus
	@JobRunnerName sysname,
	@MaxRedoQueueSize bigint,
	@MaxCommitLatencyMilliseconds bigint,
	@IsRunnable bit output
as

set nocount, xact_abort on;
set transaction isolation level read committed;

if @@trancount != 0 throw 50000, N'Running within an open transaction is not allowed', 1;

set @IsRunnable = 0;

declare
	@IsPrimary bit = 0,
	@IsClusterUnhealthy bit = 0,
	@IsNodeSuspended bit = 0;

begin try
	select
		s.is_local,
		s.is_primary_replica,
		s.is_commit_participant,
		s.synchronization_health_desc,
		s.is_suspended,
		s.redo_queue_size,
		s.log_send_queue_size,
		s.last_commit_time
	into #Snapshot
	from sys.dm_hadr_database_replica_states s
	where s.database_id = db_id(db_name())
	option (recompile);

	
	select @IsPrimary = is_primary_replica from #Snapshot where is_local = 1;
	if @IsPrimary = 0 return 0;

	select @IsClusterUnhealthy = 1 from #Snapshot where synchronization_health_desc != N'HEALTHY';
	if @IsClusterUnhealthy = 1 return 0;

	select @IsNodeSuspended = 1 from #Snapshot where is_suspended = 1;
	if @IsNodeSuspended = 1 return 0;

	declare
		@CurrentRedoQueueSize bigint,
		@CurrentPrimaryCommitTime datetime,
		@CurrentLatestSecondaryCommitTime datetime,
		@CurrentCommitLatency bigint;

	select @CurrentRedoQueueSize = max(isnull(redo_queue_size, 0)) from #Snapshot;
	if @CurrentRedoQueueSize > @MaxRedoQueueSize return 0;

	select @CurrentPrimaryCommitTime = last_commit_time from #Snapshot where is_primary_replica = 1;
	select @CurrentLatestSecondaryCommitTime = max(last_commit_time) from #Snapshot where is_primary_replica = 0;
	select @CurrentCommitLatency = datediff(millisecond, @CurrentPrimaryCommitTime, @CurrentLatestSecondaryCommitTime);
	if @CurrentCommitLatency > @MaxCommitLatencyMilliseconds return 0;

	/* Reaching this point means all checks pass, and we're runnable */
	set @IsRunnable = 1;

	return 0;

end try
begin catch
	if @@trancount != 0 rollback;
	set @IsRunnable = 0;
	throw;
end catch

return 0;

go
