create procedure JobRunner.ProcessDatabases
    @OutputTempTables bit = 0,
    @LogLevel varchar(10) = 'INFO'
as

set nocount, xact_abort on;
set transaction isolation level read committed;



/*
********************************************************************************
Precondition enforcement
********************************************************************************
*/

if @@trancount != 0 throw 50000, N'Open transaction not allowed', 1;
if @@options & 2 != 0 throw 50000, N'Implicit transactions not allowed', 1;
if @LogLevel not in ('ERROR', 'WARN', 'INFO', 'DEBUG', 'VERBOSE') throw 50000, N'Invalid @LogLevel', 1;

if has_perms_by_name(null, null, 'view any database') != 1 throw 50000, N'Missing server-level permission "view any database"', 1;

if isnull(is_srvrolemember('sysadmin'), 0) != 1
begin
    exec JobRunner.LogWarnV2 @CurrentLogLevel = @LogLevel, @Message = N'Current login is not in "sysadmin" role and you might encounter errors if modifying SQL Agent objects that belong to another login';
end

/*
********************************************************************************
End of precondition enforcement
********************************************************************************
*/





/*
********************************************************************************
Scalar variable declarations
********************************************************************************
*/

declare
    @Msg nvarchar(2000),
    @ErrorNumber int,
    @ErrorMessage nvarchar(4000);

declare
    @DatabaseName sysname,
    @JobRunnerName sysname,
    @ScheduleName sysname,
    @CategoryName sysname,
    @OwnerLoginName sysname,
    @ServerName sysname,
    @Mode nvarchar(20),
    @RecurringSecondsInterval int,
    @JobRunnerDescription nvarchar(512),
    @ReplacementRequired bit,
    @Query nvarchar(2000),
    @i int = 0,
    @MaxRetryCount int = 20;

/*
********************************************************************************
End of scalar variable declarations
********************************************************************************
*/





/*
********************************************************************************
Temporary table declarations
********************************************************************************
*/

create table #JobRunner (
    DatabaseName sysname not null,
    JobRunnerName sysname not null,
    ScheduleName sysname not null,
    CategoryName sysname not null,
    OwnerLoginName sysname not null,
    ServerName sysname not null,
    Mode nvarchar(20) not null,
    RecurringSecondsInterval int not null,
    JobRunnerDescription nvarchar(512) not null,

    primary key clustered (DatabaseName, JobRunnerName)
);

create table #SkippedDatabase (DatabaseName sysname not null primary key clustered);
create table #NonRetryableErrorNumber (ErrorNumber int not null primary key clustered);
create table #SkipDatabaseErrorNumber (ErrorNumber int not null primary key clustered);

/*
********************************************************************************
End of temporary table declarations
********************************************************************************
*/





/*
********************************************************************************
Error configuration
********************************************************************************
*/

declare
    @ErrorPermissionDeniedOnObject int = 229,
    @ErrorDatabaseDoesNotExist int = 911,
    @ErrorServerPrincipalCannotAccessDatabase int = 916,
    @ErrorAgReplicaNonReadable int = 976,
    @ErrorOnlySysAdminCanDeleteJobOwnedByDifferentLogin int = 14525;

insert into #NonRetryableErrorNumber (ErrorNumber)
values
    (111111), /* For testing */
    (@ErrorPermissionDeniedOnObject),
    (@ErrorDatabaseDoesNotExist),
    (@ErrorServerPrincipalCannotAccessDatabase),
    (@ErrorAgReplicaNonReadable),
    (@ErrorOnlySysAdminCanDeleteJobOwnedByDifferentLogin);

insert into #SkipDatabaseErrorNumber (ErrorNumber)
values
    (222222), /* For testing */
    (@ErrorAgReplicaNonReadable);

/*
********************************************************************************
End of error configuration
********************************************************************************
*/





/*
********************************************************************************
Dynamic query template setup
********************************************************************************
*/

declare @GetJobRunnerConfigQueryTemplate nvarchar(2000) = JobRunner.NormaliseLineEndings(N'
use [##DatabaseName##];

if exists (
    select 1
    from sys.tables
    where
        object_schema_name(object_id) = N''JobRunner'' and
        object_name(object_id) = N''Config''
)
begin
    select
        db_name(), JobRunnerName, ScheduleName, CategoryName, OwnerLoginName,
        ServerName, Mode, RecurringSecondsInterval, JobRunnerDescription
    from [JobRunner].[Config];
end
');


declare @JobCommandQueryTemplate nvarchar(2000) = JobRunner.NormaliseLineEndings(N'
use [##DatabaseName##];

if exists (
    select 1
    from sys.procedures
    where
        object_schema_name(object_id) = N''JobRunner'' and
        object_name(object_id) = N''RunJobs''
)
begin
    exec [JobRunner].[RunJobs] @JobRunnerName = ''##JobRunnerName##'';
end
');

/*
********************************************************************************
End of dynamic query template setup
********************************************************************************
*/




/*
********************************************************************************
Database iteration cursor

Using a cursor we get the set of [JobRunner].[Database] records and
iterate through them.
In this cursor loop we only work with databases that have not been marked soft
deleted.

For each database, if a table named [JobRunner].[Config] exists, select all
records from that table into the #JobRunner temporary table.
********************************************************************************
*/

exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'DatabaseCursor: Starting iteration';

declare DatabaseCursor cursor local forward_only static read_only
for
select DatabaseName
from JobRunner.[Database]
where IsDeleted = 0
order by DatabaseName;

open DatabaseCursor;
fetch next from DatabaseCursor into @DatabaseName;

while @@fetch_status = 0
begin
    set @Query = @GetJobRunnerConfigQueryTemplate;
    set @Query = replace(@Query, '##DatabaseName##', @DatabaseName);

    set @i = 0;
    while @i < @MaxRetryCount
    begin
        begin try
            set @i += 1;

            if has_dbaccess(@DatabaseName) != 1
            begin
                exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Skipping, has_dbaccess(...) function indicated no access', @DatabaseName = @DatabaseName;
                break;
            end

            exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Trying to retrieve "JobRunner.Config" data', @DatabaseName = @DatabaseName, @CurrentAttempt = @i, @MaxAttempts = @MaxRetryCount;

            insert into #JobRunner (
                DatabaseName, JobRunnerName, ScheduleName, CategoryName, OwnerLoginName,
                ServerName, Mode, RecurringSecondsInterval, JobRunnerDescription
            )
            exec sp_executesql @stmt = @Query;

            --throw 123456, N'An error that will be retried', 1;
            --throw 111111, N'Non-retryable error', 1;
            --throw 222222, N'Skippable database error', 1;

            exec JobRunner.LogInfoV2 @CurrentLogLevel = @LogLevel, @Message = N'Successfully retrieved "JobRunner.Config" data', @DatabaseName = @DatabaseName;

            break;
        end try
        begin catch
            if @@trancount != 0 rollback;

            if error_number() in (select ErrorNumber from #SkipDatabaseErrorNumber)
            begin
                insert into #SkippedDatabase (DatabaseName) values (@DatabaseName);
                exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Database will be skipped', @DatabaseName = @DatabaseName;
                break;
            end

            exec JobRunner.LogErrorV2 @CurrentLogLevel = @LogLevel, @Message = N'Error retrieving "JobRunner.Config" data', @DatabaseName = @DatabaseName, @CurrentAttempt = @i, @MaxAttempts = @MaxRetryCount;

            update JobRunner.[Database]
            set
                ErrorNumber = error_number(),
                ErrorMessage = error_message(),
                ErrorSeverity = error_severity(),
                ErrorState = error_state(),
                ErrorDtmUtc = getutcdate()
            where
                DatabaseName = @DatabaseName;

            if error_number() in (select ErrorNumber from #NonRetryableErrorNumber)
            begin
                exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'The last error is non-retryable and no further re-attempts will occur', @DatabaseName = @DatabaseName;
                break;
            end
        end catch
    end

    fetch next from DatabaseCursor into @DatabaseName;
end

close DatabaseCursor;
deallocate DatabaseCursor;

exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'DatabaseCursor: done';





select top 0 cast('' as char(6)) as ChangeType, *
into #MergeOutput
from JobRunner.JobRunner;

exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Merging temporary table #JobRunner into table JobRunner.JobRunner';

merge JobRunner.JobRunner with (updlock, paglock, serializable) t
using #JobRunner s
on
    t.DatabaseName = s.DatabaseName and
    t.JobRunnerName = s.JobRunnerName
when not matched by target then
    insert (
        DatabaseName, JobRunnerName, ScheduleName, CategoryName, OwnerLoginName,
        ServerName, Mode, RecurringSecondsInterval, JobRunnerDescription
    )
    values (
        s.DatabaseName, s.JobRunnerName, s.ScheduleName, s.CategoryName, s.OwnerLoginName,
        s.ServerName, s.Mode, s.RecurringSecondsInterval, s.JobRunnerDescription
    )
when matched then
    update
    set
        t.ScheduleName = s.ScheduleName,
        t.CategoryName = s.CategoryName,
        t.OwnerLoginName = s.OwnerLoginName,
        t.ServerName = s.ServerName,
        t.Mode = s.Mode,
        t.RecurringSecondsInterval = s.RecurringSecondsInterval,
        t.JobRunnerDescription = s.JobRunnerDescription,
        t.LastSeenDtmUtc = getutcdate(),
        t.IsDeleted = 0,
        t.HardDeletionDtmUtc = null,
        t.ReplacementRequired =
            case
                when t.ScheduleName != s.ScheduleName then 1
                when t.CategoryName != s.CategoryName then 1
                when t.OwnerLoginName != s.OwnerLoginName then 1
                when t.ServerName != s.ServerName then 1
                when t.Mode != s.Mode then 1
                when t.RecurringSecondsInterval != s.RecurringSecondsInterval then 1
                when t.JobRunnerDescription != s.JobRunnerDescription then 1
                else 0
            end
when not matched by source and
    t.IsDeleted = 0 and
    t.DatabaseName not in (select DatabaseName from #SkippedDatabase) then
        update
        set
            t.IsDeleted = 1,
            t.HardDeletionDtmUtc = dateadd(hour, 168, getutcdate())
when not matched by source and t.IsDeleted = 1 and getutcdate() >= t.HardDeletionDtmUtc then
    delete
output
    $action,
    coalesce(inserted.DatabaseName, deleted.DatabaseName) as DatabaseName,
    coalesce(inserted.JobRunnerName, deleted.JobRunnerName) as JobRunnerName,
    coalesce(inserted.ScheduleName, deleted.ScheduleName) as ScheduleName,
    coalesce(inserted.CategoryName, deleted.CategoryName) as CategoryName,
    coalesce(inserted.OwnerLoginName, deleted.OwnerLoginName) as OwnerLoginName,
    coalesce(inserted.ServerName, deleted.ServerName) as ServerName,
    coalesce(inserted.Mode, deleted.Mode) as Mode,
    coalesce(inserted.RecurringSecondsInterval, deleted.RecurringSecondsInterval) as RecurringSecondsInterval,
    coalesce(inserted.JobRunnerDescription, deleted.JobRunnerDescription) as JobRunnerDescription,
    coalesce(inserted.ReplacementRequired, deleted.ReplacementRequired) as ReplacementRequired,
    coalesce(inserted.FirstSeenDtmUtc, deleted.FirstSeenDtmUtc) as FirstSeenDtmUtc,
    coalesce(inserted.LastSeenDtmUtc, deleted.LastSeenDtmUtc) as LastSeenDtmUtc,
    coalesce(inserted.IsDeleted, deleted.IsDeleted) as IsDeleted,
    coalesce(inserted.HardDeletionDtmUtc, deleted.HardDeletionDtmUtc) as HardDeletionDtmUtc,
    coalesce(inserted.ErrorNumber, deleted.ErrorNumber) as ErrorNumber,
    coalesce(inserted.ErrorMessage, deleted.ErrorMessage) as ErrorMessage,
    coalesce(inserted.ErrorSeverity, deleted.ErrorSeverity) as ErrorSeverity,
    coalesce(inserted.ErrorState, deleted.ErrorState) as ErrorState,
    coalesce(inserted.ErrorDtmUtc, deleted.ErrorDtmUtc) as ErrorDtmUtc
into #MergeOutput;

exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Successfully merged temporary table #JobRunner into table JobRunner.JobRunner';





/*
**************************************************
Deleted job cursor
Handle one deleted job per iteration.
**************************************************
*/

exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'DeletedJobCursor: Starting iteration';

declare DeletedJobCursor cursor local forward_only static read_only
for
select DatabaseName, JobRunnerName
from JobRunner.JobRunner
where IsDeleted = 1
order by DatabaseName, JobRunnerName;

open DeletedJobCursor;
fetch next from DeletedJobCursor into @DatabaseName, @JobRunnerName;

while @@fetch_status = 0
begin
    set @i = 0;
    while @i < @MaxRetryCount
    begin
        begin try
            set @i += 1;

            exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Job exists already, removing', @DatabaseName = @DatabaseName, @JobName = @JobRunnerName, @CurrentAttempt = @i, @MaxAttempts = @MaxRetryCount;
            exec JobRunner.EnsureDeleteJob @JobName = @JobRunnerName, @LogLevel = @LogLevel;
            exec JobRunner.LogInfoV2 @CurrentLogLevel = @LogLevel, @Message = N'Successfully removed job', @DatabaseName = @DatabaseName, @JobName = @JobRunnerName;

            break;
        end try
        begin catch
            if @@trancount != 0 rollback;

            exec JobRunner.LogErrorV2 @CurrentLogLevel = @LogLevel, @Message = N'Error deleting job', @DatabaseName = @DatabaseName, @JobName = @JobRunnerName, @CurrentAttempt = @i, @MaxAttempts = @MaxRetryCount;

            update JobRunner.JobRunner
            set
                ErrorNumber = error_number(),
                ErrorMessage = error_message(),
                ErrorSeverity = error_severity(),
                ErrorState = error_state(),
                ErrorDtmUtc = getutcdate()
            where
                DatabaseName = @DatabaseName and
                JobRunnerName = @JobRunnerName;

            if error_number() in (select ErrorNumber from #NonRetryableErrorNumber)
            begin
                exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'The last error is non-retryable and no further re-attempts will occur', @DatabaseName = @DatabaseName, @JobName = @JobRunnerName;
                break;
            end
        end catch
    end

    fetch next from DeletedJobCursor into @DatabaseName, @JobRunnerName;
end

close DeletedJobCursor;
deallocate DeletedJobCursor;

exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'DeletedJobCursor: Done';


/*
**************************************************
Job cursor
Handle one job per iteration.
**************************************************
*/

exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'JobCursor: Starting iteration';

declare JobCursor cursor local forward_only static read_only
for
select
    DatabaseName, JobRunnerName, ScheduleName, CategoryName, OwnerLoginName, ServerName,
    Mode, RecurringSecondsInterval, JobRunnerDescription, ReplacementRequired
from JobRunner.JobRunner
where IsDeleted = 0
order by DatabaseName, JobRunnerName;

open JobCursor;
fetch next from JobCursor into @DatabaseName, @JobRunnerName, @ScheduleName, @CategoryName, @OwnerLoginName, @ServerName, @Mode, @RecurringSecondsInterval, @JobRunnerDescription, @ReplacementRequired;

while @@fetch_status = 0
begin
    set @Query = @JobCommandQueryTemplate;
    set @Query = replace(@Query, '##DatabaseName##', @DatabaseName);
    set @Query = replace(@Query, '##JobRunnerName##', @JobRunnerName);

    set @i = 0;
    while @i < @MaxRetryCount
    begin
        begin try
            set @i += 1;

            if @ReplacementRequired = 1
            begin
                exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Replacement required, job already exists, removing', @DatabaseName = @DatabaseName, @JobName = @JobRunnerName, @CurrentAttempt = @i, @MaxAttempts = @MaxRetryCount;
                exec JobRunner.EnsureDeleteJob @JobName = @JobRunnerName, @LogLevel = @LogLevel;
                exec JobRunner.LogInfoV2 @CurrentLogLevel = @LogLevel, @Message = N'Successfully removed job prior to replacement', @DatabaseName = @DatabaseName, @JobName = @JobRunnerName;
            end

            exec JobRunner.EnsureScheduleExists @ScheduleName, @OwnerLoginName, @Mode, @RecurringSecondsInterval, @LogLevel;

            

            if not exists (select job_id from msdb.dbo.sysjobs where [name] = @JobRunnerName)
            begin
                begin transaction;

                if not exists (select job_id from msdb.dbo.sysjobs with (updlock, paglock, serializable) where [name] = @JobRunnerName)
                begin
                    exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Adding job', @DatabaseName = @DatabaseName, @JobName = @JobRunnerName, @CurrentAttempt = @i, @MaxAttempts = @MaxRetryCount;
                    exec msdb.dbo.sp_add_job @job_name = @JobRunnerName, @enabled = 0, @description = @JobRunnerDescription, @category_name = @CategoryName, @owner_login_name = @OwnerLoginName;
                    exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Successfully added job', @DatabaseName = @DatabaseName, @JobName = @JobRunnerName;

                    exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Adding jobstep', @DatabaseName = @DatabaseName, @JobName = @JobRunnerName, @CurrentAttempt = @i, @MaxAttempts = @MaxRetryCount;
                    exec msdb.dbo.sp_add_jobstep @job_name = @JobRunnerName, @step_id = 1, @step_name = N'Run JobRunner.RunJobs procedure', @command = @Query;
                    exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Successfully added jobstep', @DatabaseName = @DatabaseName, @JobName = @JobRunnerName;

                    exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Attaching schedule', @DatabaseName = @DatabaseName, @JobName = @JobRunnerName, @CurrentAttempt = @i, @MaxAttempts = @MaxRetryCount;
                    exec msdb.dbo.sp_attach_schedule @job_name = @JobRunnerName, @schedule_name = @ScheduleName;
                    exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Successfully attached schedule', @DatabaseName = @DatabaseName, @JobName = @JobRunnerName;

                    exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Adding jobserver', @DatabaseName = @DatabaseName, @JobName = @JobRunnerName, @CurrentAttempt = @i, @MaxAttempts = @MaxRetryCount;
                    exec msdb.dbo.sp_add_jobserver @job_name = @JobRunnerName, @server_name = @ServerName;
                    exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Successfully added jobserver', @DatabaseName = @DatabaseName, @JobName = @JobRunnerName;

                    exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Enabling job', @DatabaseName = @DatabaseName, @JobName = @JobRunnerName, @CurrentAttempt = @i, @MaxAttempts = @MaxRetryCount;
                    exec msdb.dbo.sp_update_job @job_name = @JobRunnerName, @enabled = 1;
                    exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'Successfully enabled job', @DatabaseName = @DatabaseName, @JobName = @JobRunnerName;

                    exec JobRunner.LogInfoV2 @CurrentLogLevel = @LogLevel, @Message = N'Successfully created and configured job', @DatabaseName = @DatabaseName, @JobName = @JobRunnerName;
                end

                commit;
            end

            break;
        end try
        begin catch
            if @@trancount != 0 rollback;

            set @Msg =
                case
                    when @ReplacementRequired = 1
                    then N'Error replacing job'
                    else N'Error adding job'
                end;

            exec JobRunner.LogErrorV2 @CurrentLogLevel = @LogLevel, @Message = @Msg, @DatabaseName = @DatabaseName, @JobName = @JobRunnerName, @CurrentAttempt = @i, @MaxAttempts = @MaxRetryCount;

            update JobRunner.JobRunner
            set
                ErrorNumber = error_number(),
                ErrorMessage = error_message(),
                ErrorSeverity = error_severity(),
                ErrorState = error_state(),
                ErrorDtmUtc = getutcdate()
            where
                DatabaseName = @DatabaseName and
                JobRunnerName = @JobRunnerName;

            if error_number() in (select ErrorNumber from #NonRetryableErrorNumber)
            begin
                exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'The last error is non-retryable and no further re-attempts will occur', @DatabaseName = @DatabaseName, @JobName = @JobRunnerName;
                break;
            end
        end catch
    end

    fetch next from JobCursor into @DatabaseName, @JobRunnerName, @ScheduleName, @CategoryName, @OwnerLoginName, @ServerName, @Mode, @RecurringSecondsInterval, @JobRunnerDescription, @ReplacementRequired;
end

close JobCursor;
deallocate JobCursor;

exec JobRunner.LogVerboseV2 @CurrentLogLevel = @LogLevel, @Message = N'JobCursor: Done';


if @OutputTempTables = 1
begin
    select '' as [Temporary table = #MergeOutput], * from #MergeOutput;
    select '' as [Temporary table = #JobRunner], * from #JobRunner;
end

return 0;
