create procedure JobRunner.AddReplicatorJob
    @CategoryName sysname = N'Database Maintenance',
    @ScheduleName sysname = N'JobRunner job replicator schedule',
    @JobName sysname = N'JobRunner job replicator',
    @OwnerLoginName sysname = N'sa',
    @ServerName sysname = N'(local)',
    @RecurringSecondsInterval int = 10,
    @MaxAttempts int = 20,
    @LogLevel varchar(10) = 'INFO'
as

set nocount, xact_abort on;
set transaction isolation level read committed;

if @@trancount != 0 throw 50000, N'Open transaction not allowed', 1;
if @@options & 2 != 0 throw 50000, N'Implicit transactions not allowed', 1;

declare
    @DatabaseName sysname = db_name(),
    @JobDescription nvarchar(512) = N'This job checks each database for any new job configurations, and installs them.',
    @i int = 0;

declare @CheckObjectsExistCommand nvarchar(max) = JobRunner.NormaliseLineEndings(N'
use master;

if not exists (
    select 1
    from sys.procedures
    where
        object_schema_name(object_id) = N''JobRunner'' and
        object_name(object_id) = N''MergeDatabases''
)
begin
    throw 50000, N''Missing procedure: "JobRunner.MergeDatabases"'', 1;
end

if not exists (
    select 1
    from sys.procedures
    where
        object_schema_name(object_id) = N''JobRunner'' and
        object_name(object_id) = N''ProcessDatabases''
)
begin;
    throw 50000, N''Missing procedure: "JobRunner.ProcessDatabases"'', 1;
end
');

declare @MergeDatabasesCommand nvarchar(max) = JobRunner.NormaliseLineEndings(N'
use master;
exec JobRunner.MergeDatabases;
');

declare @ProcessDatabasesCommand nvarchar(max) = JobRunner.NormaliseLineEndings(N'
use master;
exec JobRunner.ProcessDatabases;
');


while @i < @MaxAttempts
begin
    begin try
        set @i += 1;

        exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Adding replicator job', @DatabaseName = @DatabaseName, @JobName = @JobName, @CategoryName = @CategoryName, @ScheduleName = @ScheduleName, @CurrentAttempt = @i, @MaxAttempts = @MaxAttempts;

        exec JobRunner.EnsureDeleteJob @JobName, @LogLevel = @LogLevel;
        exec JobRunner.EnsureScheduleExists @ScheduleName, @OwnerLoginName, 'recurring', @RecurringSecondsInterval, @LogLevel;

        begin transaction;

        exec msdb.dbo.sp_add_job @job_name = @JobName, @enabled = 0, @description = @JobDescription, @category_name = @CategoryName, @owner_login_name = @OwnerLoginName;
        exec msdb.dbo.sp_add_jobstep @job_name = @JobName, @step_id = 1, @step_name = N'Check objects exist', @command = @CheckObjectsExistCommand, @on_success_action = 3;
        exec msdb.dbo.sp_add_jobstep @job_name = @JobName, @step_id = 2, @step_name = N'Merge database details', @command = @MergeDatabasesCommand, @on_success_action = 3;
        exec msdb.dbo.sp_add_jobstep @job_name = @JobName, @step_id = 3, @step_name = N'Process databases', @command = @ProcessDatabasesCommand;
        exec msdb.dbo.sp_attach_schedule @job_name = @JobName, @schedule_name = @ScheduleName;
        exec msdb.dbo.sp_add_jobserver @job_name = @JobName, @server_name = @ServerName;
        exec msdb.dbo.sp_update_job @job_name = @JobName, @enabled = 1;
        exec msdb.dbo.sp_start_job @job_name = @JobName;

        commit;

        exec JobRunner.LogInfoV2 @CurrentLogLevel = @LogLevel, @Message = N'Successfully added replicator job', @DatabaseName = @DatabaseName, @JobName = @JobName, @CategoryName = @CategoryName, @ScheduleName = @ScheduleName;

        return 0;
    end try
    begin catch
        if @@trancount != 0 rollback;
        exec JobRunner.LogErrorV2 @CurrentLogLevel = @LogLevel, @Message = N'Error adding replicator job', @DatabaseName = @DatabaseName, @JobName = @JobName, @CategoryName = @CategoryName, @ScheduleName = @ScheduleName;
        if @i = @MaxAttempts throw;
    end catch
end

return 0;
