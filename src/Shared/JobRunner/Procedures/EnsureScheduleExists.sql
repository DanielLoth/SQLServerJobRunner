create procedure JobRunner.EnsureScheduleExists
    @ScheduleName sysname,
    @OwnerLoginName sysname = N'sa',
    @Mode nvarchar(20) = N'Recurring',
    @RecurringSecondsInterval int = 60,
    @LogLevel varchar(10) = 'INFO'
as

set nocount, xact_abort on;
set transaction isolation level read committed;

if @@trancount != 0 throw 50000, N'Open transaction not allowed', 1;
if @@options & 2 != 0 throw 50000, N'Implicit transactions not allowed', 1;
if @Mode not in (N'CPUIdle', N'Recurring') throw 50000, N'Invalid @Mode. Use ''CPUIdle'' or ''Recurring''', 1;

if isnull(is_srvrolemember('sysadmin'), 0) != 1
begin
    exec JobRunner.LogWarnV2 @CurrentLogLevel = @LogLevel, @Message = N'Current login is not in "sysadmin" role and you might encounter errors if modifying SQL Agent objects that belong to another login';
end

declare
    @DatabaseName sysname = db_name(),
    @OwnerLoginSid varbinary(85),
    @FrequencyType int = case @Mode when N'CPUIdle' then 128 else 4 end, /* 128 = CPU Idle, 4 = daily */
    @FrequencyInterval int = case @Mode when N'CPUIdle' then 0 else 1 end, /* 0 and 1 = unused */
    @FrequencySubDayType int = case @Mode when N'CPUIdle' then 0 else 2 end, /* 0 = unused, 2 = seconds */
    @FrequencySubDayInterval int = case @Mode when N'CPUIdle' then 0 else @RecurringSecondsInterval end;

begin try
    exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Checking if schedule is missing', @DatabaseName = @DatabaseName, @ScheduleName = @ScheduleName;

    if not exists (select [name] from msdb.dbo.sysschedules where [name] = @ScheduleName)
    begin
        exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Re-checking if schedule is missing (with updlock)', @DatabaseName = @DatabaseName, @ScheduleName = @ScheduleName;

        begin transaction;

        if not exists (select [name] from msdb.dbo.syscategories with (paglock, serializable, updlock) where [name] = @ScheduleName)
        begin
            exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Creating schedule', @DatabaseName = @DatabaseName, @ScheduleName = @ScheduleName;

            exec msdb.dbo.sp_add_schedule
                @schedule_name = @ScheduleName,
                @enabled = 1,
                @freq_type = @FrequencyType,
                @freq_interval = @FrequencyInterval,
                @freq_subday_type = @FrequencySubDayType,
                @freq_subday_interval = @FrequencySubDayInterval,
                @freq_relative_interval = 0,
                @freq_recurrence_factor = 0,
                @active_start_date = 20220101,
                @active_end_date = 99991231,
                @active_start_time = 0,
                @active_end_time = 235959,
                @owner_login_name = @OwnerLoginName;

            exec JobRunner.LogInfoV2 @CurrentLogLevel = @LogLevel, @Message = N'Successfully created schedule', @DatabaseName = @DatabaseName, @ScheduleName = @ScheduleName;
        end

        commit;

        return 0;
    end

    set @OwnerLoginSid = suser_sid(@OwnerLoginName, 0);

    exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Checking if schedule has been modified and not in desired state', @DatabaseName = @DatabaseName, @ScheduleName = @ScheduleName;

    if exists (
        select [name]
        from msdb.dbo.sysschedules
        where
            [name] = @ScheduleName and
            (
                [enabled] != 1 or
                freq_type != @FrequencyType or
                freq_interval != @FrequencyInterval or
                freq_subday_type != @FrequencySubDayType or
                freq_subday_interval != @FrequencySubDayInterval or
                freq_relative_interval != 0 or
                freq_recurrence_factor != 0 or
                active_start_date != 20220101 or
                active_end_date != 99991231 or
                active_start_time != 0 or
                active_end_time != 235959 or
                owner_sid != @OwnerLoginSid
            )
    )
    begin
        exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Re-checking if schedule has been modified and not in desired state (with updlock)', @DatabaseName = @DatabaseName, @ScheduleName = @ScheduleName;

        begin transaction;

        if exists (
            select [name]
            from msdb.dbo.sysschedules with (paglock, serializable, updlock)
            where
                [name] = @ScheduleName and
                (
                    [enabled] != 1 or
                    freq_type != @FrequencyType or
                    freq_interval != @FrequencyInterval or
                    freq_subday_type != @FrequencySubDayType or
                    freq_subday_interval != @FrequencySubDayInterval or
                    freq_relative_interval != 0 or
                    freq_recurrence_factor != 0 or
                    active_start_date != 20220101 or
                    active_end_date != 99991231 or
                    active_start_time != 0 or
                    active_end_time != 235959 or
                    owner_sid != @OwnerLoginSid
                )
        )
        begin
            exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Updating schedule to desired state', @DatabaseName = @DatabaseName, @ScheduleName = @ScheduleName;

            exec msdb.dbo.sp_update_schedule
                @name = @ScheduleName,
                @enabled = 1,
                @freq_type = @FrequencyType,
                @freq_interval = @FrequencyInterval,
                @freq_subday_type = @FrequencySubDayType,
                @freq_subday_interval = @FrequencySubDayInterval,
                @freq_relative_interval = 0,
                @freq_recurrence_factor = 0,
                @active_start_date = 20220101,
                @active_end_date = 99991231,
                @active_start_time = 0,
                @active_end_time = 235959,
                @owner_login_name = @OwnerLoginName;

            exec JobRunner.LogInfoV2 @CurrentLogLevel = @LogLevel, @Message = N'Successfully updated schedule to desired state', @DatabaseName = @DatabaseName, @ScheduleName = @ScheduleName;
        end

        commit;

        return 0;
    end
end try
begin catch
    if @@trancount != 0 rollback;
    exec JobRunner.LogErrorV2 @CurrentLogLevel = @LogLevel, @Message = N'Error ensuring schedule exists', @DatabaseName = @DatabaseName, @ScheduleName = @ScheduleName;
    throw;
end catch

return 0;

go
