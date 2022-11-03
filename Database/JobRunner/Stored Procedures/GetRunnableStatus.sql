create procedure JobRunner.GetRunnableStatus
	@JobRunnerName sysname,
	@DatabaseName sysname,
	@IsPrimary bit,
	@MaxRedoQueueSize bigint,
	@MaxCommitLatencyMilliseconds bigint,
	@IsRunnable bit output
as

set nocount, xact_abort on;
set transaction isolation level read committed;

set @IsRunnable = 0;

if @@trancount != 0 throw 50000, N'Running within an open transaction is not allowed', 1;


/* Definite non-primary. No further work. */
if @IsPrimary = 0 return 0;

/* Not clustered, so runnable. No further work. */
if @IsPrimary is null
begin
	set @IsRunnable = 1;
	return 0;
end

begin try
	select
		s.is_local,
		s.is_primary_replica,
		s.is_commit_participant,
		s.synchronization_health_desc,
		s.redo_queue_size,
		s.log_send_queue_size,
		s.last_commit_time
	into #Snapshot
	from sys.dm_hadr_database_replica_states s
		inner join sys.availability_databases_cluster c
		on
			s.group_id = c.group_id and
			s.group_database_id = c.group_database_id
	where
		c.database_name = @DatabaseName
	option (recompile);

	declare
		@HealthStatus nvarchar(60),
		@CurrentRedoQueueSize bigint,
		@CurrentPrimaryCommitTime datetime,
		@CurrentLatestSecondaryCommitTime datetime,
		@CurrentCommitLatency bigint;

	select @HealthStatus = synchronization_health_desc from #Snapshot where is_primary_replica = 1;
	if @HealthStatus != N'HEALTHY' return 0;

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
