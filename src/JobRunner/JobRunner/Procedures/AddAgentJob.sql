create procedure JobRunner.AddAgentJob
    @JobRunnerName sysname,
    @CategoryName sysname,
    @ScheduleName sysname,
    @ServerName sysname,
    @DatabaseName sysname,
    @OwnerLoginName sysname,
    @Mode nvarchar(20),
    @RecurringSecondsInterval int = -1,
    @DeleteJobHistory bit = 0,
    @MaxAttempts int = 20,
    @LogLevel varchar(10) = 'INFO'
as

set nocount, xact_abort on;
set transaction isolation level read committed;

if @@trancount != 0 throw 50000, N'Open transaction not allowed', 1;
if @@options & 2 != 0 throw 50000, N'Implicit transactions not allowed', 1;
if @Mode not in (N'CPUIdle', N'Recurring') throw 50000, N'Invalid @Mode. Use ''CPUIdle'' or ''Recurring''', 1;
if @Mode = N'Recurring' and @RecurringSecondsInterval < 10 throw 50000, N'Invalid @RecurringSecondsInterval - specify a value greater than or equal to 10', 1;

declare
    @JobStepName sysname = N'Run JobRunner.RunJobs procedure',
    @JobDescription nvarchar(512) = N'Run background job stored procedures',
    @i int = 0;

declare @Command nvarchar(2000) = JobRunner.NormaliseLineEndings(N'
use [##DatabaseName##];

if exists (
    select 1
    from sys.procedures
    where
        object_schema_name(object_id) = N''JobRunner'' and
        object_name(object_id) = N''RunJobs''
)
begin
    exec JobRunner.RunJobs @JobRunnerName = ''##JobRunnerName##'';
end
');

set @Command = replace(@Command, '##DatabaseName##', @DatabaseName);
set @Command = replace(@Command, '##JobRunnerName##', @JobRunnerName);

while @i < @MaxAttempts
begin
    begin try
        set @i += 1;

        exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Adding job', @DatabaseName = @DatabaseName, @JobName = @JobRunnerName, @CategoryName = @CategoryName, @ScheduleName = @ScheduleName, @CurrentAttempt = @i, @MaxAttempts = @MaxAttempts;

        exec JobRunner.EnsureCategoryExists @CategoryName = @CategoryName, @LogLevel = @LogLevel;
        exec JobRunner.EnsureScheduleExists @ScheduleName = @ScheduleName, @OwnerLoginName = @OwnerLoginName, @Mode = @Mode, @RecurringSecondsInterval = @RecurringSecondsInterval, @LogLevel = @LogLevel;
        exec JobRunner.EnsureDeleteJob @JobName = @JobRunnerName, @DeleteHistory = @DeleteJobHistory, @LogLevel = @LogLevel;

        begin transaction;

        exec msdb.dbo.sp_add_job @job_name = @JobRunnerName, @enabled = 0, @description = @JobDescription, @category_name = @CategoryName, @owner_login_name = @OwnerLoginName;
        exec msdb.dbo.sp_add_jobstep @job_name = @JobRunnerName, @step_id = 1, @step_name = @JobStepName, @command = @Command;
        exec msdb.dbo.sp_attach_schedule @job_name = @JobRunnerName, @schedule_name = @ScheduleName
        exec msdb.dbo.sp_add_jobserver @job_name = @JobRunnerName, @server_name = @ServerName;
        exec msdb.dbo.sp_update_job @job_name = @JobRunnerName, @enabled = 1;

        commit;

        exec JobRunner.LogInfoV2 @CurrentLogLevel = @LogLevel, @Message = N'Successfully added job', @DatabaseName = @DatabaseName, @JobName = @JobRunnerName, @CategoryName = @CategoryName, @ScheduleName = @ScheduleName;

        return 0;
    end try
    begin catch
        if @@trancount != 0 rollback;
        exec JobRunner.LogErrorV2 @CurrentLogLevel = @LogLevel, @Message = N'Error adding job', @DatabaseName = @DatabaseName, @JobName = @JobRunnerName, @CategoryName = @CategoryName, @ScheduleName = @ScheduleName;
        if @i = @MaxAttempts throw;
    end catch
end

go
