create procedure JobRunner.EnsureScheduleExistsWithRetry
    @ScheduleName sysname,
    @OwnerLoginName sysname = N'sa',
    @Mode nvarchar(20) = N'Recurring',
    @RecurringSecondsInterval int = 60,
    @MaxAttempts int = 20,
    @LogLevel varchar(10) = 'INFO'
as

set nocount, xact_abort on;
set transaction isolation level read committed;

if @@trancount != 0 throw 50000, N'Open transaction not allowed', 1;
if @@options & 2 != 0 throw 50000, N'Implicit transactions not allowed', 1;
if @Mode not in (N'CPUIdle', N'Recurring') throw 50000, N'Invalid @Mode. Use ''CPUIdle'' or ''Recurring''', 1;

declare
    @i int = 0,
    @DatabaseName sysname = db_name();

declare @NonRetryableErrorNumber table (ErrorNumber int primary key);
insert into @NonRetryableErrorNumber (ErrorNumber)
values
    /* Only owner of a job schedule or members of sysadmin role can modify or delete the job schedule. */
    (14394);

while @i < @MaxAttempts
begin
    begin try
        set @i += 1;

        exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Ensuring schedule exists', @DatabaseName = @DatabaseName, @ScheduleName = @ScheduleName, @CurrentAttempt = @i, @MaxAttempts = @MaxAttempts;
        exec JobRunner.EnsureScheduleExists @ScheduleName = @ScheduleName, @OwnerLoginName = @OwnerLoginName, @Mode = @Mode, @RecurringSecondsInterval = @RecurringSecondsInterval, @LogLevel = @LogLevel;

        break;
    end try
    begin catch
        if @@trancount != 0 rollback;

        exec JobRunner.LogErrorV2 @CurrentLogLevel = @LogLevel, @Message = N'Error ensuring existence and desired state of schedule', @DatabaseName = @DatabaseName, @ScheduleName = @ScheduleName, @CurrentAttempt = @i, @MaxAttempts = @MaxAttempts;

        if error_number() in (select ErrorNumber from @NonRetryableErrorNumber)
        begin
            exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'The last error is non-retryable and no further re-attempts will occur', @DatabaseName = @DatabaseName, @ScheduleName = @ScheduleName;
            throw;
        end

        if @i = @MaxAttempts throw;
    end catch
end

return 0;

go
