declare @CategoryName sysname = N'$(CategoryName)';
print N'Parameter "CategoryName" has value "' + @CategoryName + '".';

declare @JobName sysname = N'$(ReplicatorJobName)';
print N'Parameter "ReplicatorJobName" has value "' + @JobName + '".';

declare @OwnerLoginName sysname = N'$(OwnerLoginName)';
print N'Parameter "OwnerLoginName" has value "' + @OwnerLoginName + '".';

declare @ServerName sysname = N'$(ServerName)';
print N'Parameter "ServerName" has value "' + @ServerName + '".';

declare @ScheduleName sysname = N'$(ScheduleName)';
print N'Parameter "ScheduleName" has value "' + @ScheduleName + '".';

declare @RecurringSecondsInterval int = 60;
begin try
    set @RecurringSecondsInterval = cast('$(RecurringSecondsInterval)' as int);
end try
begin catch
    print @RecurringSecondsInterval;
    throw 50000, N'Parameter "RecurringSecondsInterval" was specified with invalid value "$(RecurringSecondsInterval)". Please specify an integer value between 10 and 900 (inclusive).', 1;
end catch

if @RecurringSecondsInterval < 10 or @RecurringSecondsInterval > 900
begin;
    throw 50000, N'Please specify a value between 10 and 900 (inclusive) for parameter "RecurringSecondsInterval".', 1;
end

print N'Parameter "RecurringSecondsInterval" has value "' + cast(@RecurringSecondsInterval as varchar(10)) + '".';

exec JobRunner.AddReplicatorJob
    @CategoryName = @CategoryName,
    @ScheduleName = @ScheduleName,
    @JobName = @JobName,
    @OwnerLoginName = @OwnerLoginName,
    @ServerName = @ServerName,
    @RecurringSecondsInterval = @RecurringSecondsInterval,
    @LogLevel = 'verbose';
