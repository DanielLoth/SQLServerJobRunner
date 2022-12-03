create procedure JobRunner.EnsureDeleteJobWithRetry
    @JobName sysname,
    @DeleteHistory bit = 0,
    @DeleteUnusedSchedule bit = 0,
    @MaxAttempts int = 20,
    @LogLevel varchar(10) = 'INFO'
as

set nocount, xact_abort on;
set transaction isolation level read committed;

if @@trancount != 0 throw 50000, N'Open transaction not allowed', 1;
if @@options & 2 != 0 throw 50000, N'Implicit transactions not allowed', 1;

declare
    @i int = 0,
    @DatabaseName sysname = db_name();

declare @NonRetryableErrorNumber table (ErrorNumber int primary key);

while @i < @MaxAttempts
begin
    begin try
        set @i += 1;

        exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Deleting job', @DatabaseName = @DatabaseName, @JobName = @JobName, @CurrentAttempt = @i, @MaxAttempts = @MaxAttempts;
        exec JobRunner.EnsureDeleteJob @JobName = @JobName, @DeleteHistory = @DeleteHistory, @DeleteUnusedSchedule = @DeleteUnusedSchedule, @LogLevel = @LogLevel;

        break;
    end try
    begin catch
        if @@trancount != 0 rollback;

        exec JobRunner.LogErrorV2 @CurrentLogLevel = @LogLevel, @Message = N'Error deleting job', @DatabaseName = @DatabaseName, @JobName = @JobName, @CurrentAttempt = @i, @MaxAttempts = @MaxAttempts;

        if error_number() in (select ErrorNumber from @NonRetryableErrorNumber)
        begin
            exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'The last error is non-retryable and no further re-attempts will occur', @DatabaseName = @DatabaseName, @JobName = @JobName;
            throw;
        end

        if @i = @MaxAttempts throw;
    end catch
end

return 0;

go
