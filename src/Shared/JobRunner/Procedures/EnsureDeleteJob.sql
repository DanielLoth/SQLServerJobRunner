create procedure JobRunner.EnsureDeleteJob
    @JobName sysname,
    @DeleteHistory bit = 0,
    @DeleteUnusedSchedule bit = 0,
    @LogLevel varchar(10) = 'INFO'
as

set nocount, xact_abort on;
set transaction isolation level read committed;

if @@trancount != 0 throw 50000, N'Open transaction not allowed', 1;
if @@options & 2 != 0 throw 50000, N'Implicit transactions not allowed', 1;

if isnull(is_srvrolemember('sysadmin'), 0) != 1
begin
    exec JobRunner.LogWarnV2 @CurrentLogLevel = @LogLevel, @Message = N'Current login is not in "sysadmin" role and you might encounter errors if modifying SQL Agent objects that belong to another login';
end

declare @DatabaseName sysname = db_name();

begin try
    exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Checking if job exists and needs to be deleted', @DatabaseName = @DatabaseName, @JobName = @JobName;

    if exists (select [name] from msdb.dbo.sysjobs where [name] = @JobName)
    begin
        exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Re-checking if job exists and needs to be deleted (with updlock)', @DatabaseName = @DatabaseName, @JobName = @JobName;

        begin transaction;

        if exists (select [name] from msdb.dbo.sysjobs with (paglock, serializable, updlock) where [name] = @JobName)
        begin
            exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Deleting job', @DatabaseName = @DatabaseName, @JobName = @JobName;
            exec msdb.dbo.sp_delete_job @job_name = @JobName, @delete_history = @DeleteHistory, @delete_unused_schedule = @DeleteUnusedSchedule;
            exec JobRunner.LogInfoV2 @CurrentLogLevel = @LogLevel, @Message = N'Successfully deleted job', @DatabaseName = @DatabaseName, @JobName = @JobName;
        end

        commit;
    end
end try
begin catch
    if @@trancount != 0 rollback;
    exec JobRunner.LogErrorV2 @CurrentLogLevel = @LogLevel, @Message = N'Error ensuring job deletion', @DatabaseName = @DatabaseName, @JobName = @JobName;
    throw;
end catch

return 0;

go
