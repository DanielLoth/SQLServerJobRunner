create procedure JobRunner.LogVerboseV2
    @CurrentLogLevel varchar(10),
    @Message nvarchar(200),
    @DatabaseName sysname = null,
    @JobName sysname = null,
    @CategoryName sysname = null,
    @ScheduleName sysname = null,
    @CurrentAttempt int = null,
    @MaxAttempts int = null
as
exec JobRunner.LogMessageV2
    @CurrentLogLevel = @CurrentLogLevel,
    @Prefix = 'VERBOSE',
    @Message = @Message,
    @DatabaseName = @DatabaseName,
    @JobName = @JobName,
    @CategoryName = @CategoryName,
    @ScheduleName = @ScheduleName,
    @CurrentAttempt = @CurrentAttempt,
    @MaxAttempts = @MaxAttempts;

go

create procedure JobRunner.LogDebugV2
    @CurrentLogLevel varchar(10),
    @Message nvarchar(200),
    @DatabaseName sysname = null,
    @JobName sysname = null,
    @CategoryName sysname = null,
    @ScheduleName sysname = null,
    @CurrentAttempt int = null,
    @MaxAttempts int = null
as
exec JobRunner.LogMessageV2
    @CurrentLogLevel = @CurrentLogLevel,
    @Prefix = 'DEBUG',
    @Message = @Message,
    @DatabaseName = @DatabaseName,
    @JobName = @JobName,
    @CategoryName = @CategoryName,
    @ScheduleName = @ScheduleName,
    @CurrentAttempt = @CurrentAttempt,
    @MaxAttempts = @MaxAttempts;

go

create procedure JobRunner.LogInfoV2
    @CurrentLogLevel varchar(10),
    @Message nvarchar(200),
    @DatabaseName sysname = null,
    @JobName sysname = null,
    @CategoryName sysname = null,
    @ScheduleName sysname = null,
    @CurrentAttempt int = null,
    @MaxAttempts int = null
as
exec JobRunner.LogMessageV2
    @CurrentLogLevel = @CurrentLogLevel,
    @Prefix = 'INFO',
    @Message = @Message,
    @DatabaseName = @DatabaseName,
    @JobName = @JobName,
    @CategoryName = @CategoryName,
    @ScheduleName = @ScheduleName,
    @CurrentAttempt = @CurrentAttempt,
    @MaxAttempts = @MaxAttempts;

go

create procedure JobRunner.LogWarnV2
    @CurrentLogLevel varchar(10),
    @Message nvarchar(200),
    @DatabaseName sysname = null,
    @JobName sysname = null,
    @CategoryName sysname = null,
    @ScheduleName sysname = null,
    @CurrentAttempt int = null,
    @MaxAttempts int = null
as
exec JobRunner.LogMessageV2
    @CurrentLogLevel = @CurrentLogLevel,
    @Prefix = 'WARN',
    @Message = @Message,
    @DatabaseName = @DatabaseName,
    @JobName = @JobName,
    @CategoryName = @CategoryName,
    @ScheduleName = @ScheduleName,
    @CurrentAttempt = @CurrentAttempt,
    @MaxAttempts = @MaxAttempts;

go

create procedure JobRunner.LogErrorV2
    @CurrentLogLevel varchar(10),
    @Message nvarchar(200) = null,
    @DatabaseName sysname = null,
    @JobName sysname = null,
    @CategoryName sysname = null,
    @ScheduleName sysname = null,
    @CurrentAttempt int = null,
    @MaxAttempts int = null,
    @IncludeErrorContext bit = 1
as
exec JobRunner.LogMessageV2
    @CurrentLogLevel = @CurrentLogLevel,
    @Prefix = 'ERROR',
    @Message = @Message,
    @DatabaseName = @DatabaseName,
    @JobName = @JobName,
    @CategoryName = @CategoryName,
    @ScheduleName = @ScheduleName,
    @CurrentAttempt = @CurrentAttempt,
    @MaxAttempts = @MaxAttempts,
    @IncludeErrorContext = @IncludeErrorContext;

go

create procedure JobRunner.LogMessageV2
    @CurrentLogLevel varchar(10),
    @Prefix varchar(10),
    @Message nvarchar(200) = null,
    @DatabaseName sysname = null,
    @JobName sysname = null,
    @CategoryName sysname = null,
    @ScheduleName sysname = null,
    @CurrentAttempt int = null,
    @MaxAttempts int = null,
    @IncludeErrorContext bit = 0
as

if @CurrentLogLevel not in ('ERROR', 'WARN', 'INFO', 'DEBUG', 'VERBOSE') throw 50000, N'Invalid @CurrentLogLevel', 1;
if @Prefix not in ('ERROR', 'WARN', 'INFO', 'DEBUG', 'VERBOSE') throw 50000, N'Invalid @Prefix', 1;

declare @ShouldLog bit =
    case
        when @CurrentLogLevel = 'VERBOSE' and @Prefix in ('ERROR', 'WARN', 'INFO', 'DEBUG', 'VERBOSE') then 1
        when @CurrentLogLevel = 'DEBUG'   and @Prefix in ('ERROR', 'WARN', 'INFO', 'DEBUG') then 1
        when @CurrentLogLevel = 'INFO'    and @Prefix in ('ERROR', 'WARN', 'INFO') then 1
        when @CurrentLogLevel = 'WARN'    and @Prefix in ('ERROR', 'WARN') then 1
        when @CurrentLogLevel = 'ERROR'   and @Prefix in ('ERROR') then 1
        else 0
    end;

if @ShouldLog = 0
begin
    return 0; /* No logging to be performed presently */
end

declare @IsInSysAdminRole bit = isnull(is_srvrolemember('sysadmin'), 0);
declare @CurrentLogin sysname = suser_sname();
declare @CurrentSid varbinary(85) = suser_sid();


declare @LogMessage nvarchar(max) = @Prefix + N': ';

if @Message is not null
begin
    set @LogMessage += N'Message: ' + @Message + N'. ';
end

if @DatabaseName is not null
begin
    set @LogMessage += N'Database: "' + @DatabaseName + N'". ';
end

if @JobName is not null
begin
    set @LogMessage += N'Job name: "' + @JobName + N'". ';
end

if @CategoryName is not null
begin
    set @LogMessage += N'Category name: "' + @CategoryName + N'". ';
end

if @ScheduleName is not null
begin
    set @LogMessage += N'Schedule name: "' + @ScheduleName + N'". ';
end

if @CurrentAttempt is not null and @MaxAttempts is not null
begin
    set @LogMessage += N'Attempt ' + cast(@CurrentAttempt as nvarchar(20)) + N' of ' + cast(@MaxAttempts as nvarchar(20)) + N'. ';
end

set @LogMessage += N'Current login: "' + isnull(@CurrentLogin, '<unknown>') + N'". ';
set @LogMessage += N'Current SID: "' + isnull(convert(varchar(200), @CurrentSid, 1), '<unknown>') + N'". ';
set @LogMessage += N'In "sysadmin" role: ' + case when @IsInSysAdminRole = 1 then 'True' else 'False' end + N'. ';

if @IncludeErrorContext = 1 and error_number() is not null
begin
    set @LogMessage +=
        N'Error number: ' + isnull(cast(error_number() as nvarchar(20)), '<unknown>') + N'. ' +
        N'Procedure: "' + isnull(error_procedure(), '<unknown>') + N'". ' +
        N'Severity: ' + isnull(cast(error_severity() as nvarchar(20)), '<unknown>') + N'. ' +
        N'State: ' + isnull(cast(error_state() as nvarchar(20)), '<unknown>') + N'. ' +
        N'Line: ' + isnull(cast(error_line() as nvarchar(20)), '<unknown>') + N'. ' +
        N'Error message: ' + isnull(error_message(), '<unknown>');
end

raiserror(@LogMessage, 0, 1) with nowait;

go
