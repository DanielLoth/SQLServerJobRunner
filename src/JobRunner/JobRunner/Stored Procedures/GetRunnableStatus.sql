create procedure JobRunner.GetRunnableStatus
	@JobRunnerName sysname,
	@MaxSyncSecondaryRedoQueueSize bigint,
	@MaxAsyncSecondaryRedoQueueSize bigint,
	@MaxSyncSecondaryCommitLatencyMilliseconds bigint,
	@MaxAsyncSecondaryCommitLatencyMilliseconds bigint,
	@IsRunnable bit output
as

set nocount, xact_abort on;
set transaction isolation level read committed;

if @@trancount != 0 throw 50000, N'Running within an open transaction is not allowed', 1;

set @IsRunnable = 0;

declare
	@IsPrimary bit = null,
	@IsAnyNodeUnhealthy bit = 0,
	@IsAnyNodeSuspended bit = 0,
	@IsPrimaryOnline bit = 0,
	@PrimaryLastCommitTime datetime,
	@MaxAsyncSecondaryLastCommitTime datetime,
	@MaxSyncSecondaryLastCommitTime datetime,
	@TimeDiff bigint,
	@CurrentMaxSyncSecondaryRedoQueueSize bigint,
	@CurrentMaxAsyncSecondaryRedoQueueSize bigint;

begin try
	select
		is_local,
		is_primary_replica,
		is_commit_participant,
		synchronization_health_desc,
		database_state_desc,
		is_suspended,
		redo_queue_size,
		log_send_queue_size,
		last_commit_time
	into #Snapshot
	from sys.dm_hadr_database_replica_states
	where database_id = db_id(db_name())
	option (recompile);

	
	select @IsPrimary = is_primary_replica from #Snapshot where is_local = 1;

	if @IsPrimary is null
	begin
		set @IsRunnable = 1;
		return;
	end

	if @IsPrimary = 0 return 0;

	select @IsPrimaryOnline = 1 from #Snapshot where is_local = 1 and database_state_desc = N'ONLINE';
	if @IsPrimaryOnline = 0 return 0;

	select @IsAnyNodeUnhealthy = 1 from #Snapshot where synchronization_health_desc != N'HEALTHY';
	if @IsAnyNodeUnhealthy = 1 return 0;

	select @IsAnyNodeSuspended = 1 from #Snapshot where is_suspended = 1;
	if @IsAnyNodeSuspended = 1 return 0;

	select @PrimaryLastCommitTime = last_commit_time from #Snapshot where is_primary_replica = 1;

	select @MaxSyncSecondaryLastCommitTime = isnull(max(last_commit_time), @PrimaryLastCommitTime)
	from #Snapshot
	where is_primary_replica = 0 and is_commit_participant = 1;

	set @TimeDiff = abs(datediff(millisecond, @PrimaryLastCommitTime, @MaxSyncSecondaryLastCommitTime));
	if @TimeDiff > @MaxSyncSecondaryCommitLatencyMilliseconds
	begin
		return 0;
	end

	select @MaxAsyncSecondaryLastCommitTime = isnull(max(last_commit_time), @PrimaryLastCommitTime)
	from #Snapshot
	where is_primary_replica = 0 and is_commit_participant = 0;

	set @TimeDiff = abs(datediff(millisecond, @PrimaryLastCommitTime, @MaxAsyncSecondaryLastCommitTime));
	if @TimeDiff > @MaxAsyncSecondaryCommitLatencyMilliseconds
	begin
		return 0;
	end

	select @CurrentMaxSyncSecondaryRedoQueueSize = isnull(max(redo_queue_size), 0)
	from #Snapshot
	where is_primary_replica = 0 and is_commit_participant = 1;

	if @CurrentMaxSyncSecondaryRedoQueueSize > @MaxSyncSecondaryRedoQueueSize return 0;

	select @CurrentMaxAsyncSecondaryRedoQueueSize = isnull(max(redo_queue_size), 0)
	from #Snapshot
	where is_primary_replica = 0 and is_commit_participant = 0;

	if @CurrentMaxAsyncSecondaryRedoQueueSize > @MaxAsyncSecondaryRedoQueueSize return 0;

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
