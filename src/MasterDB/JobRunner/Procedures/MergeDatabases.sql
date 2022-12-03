create procedure JobRunner.MergeDatabases
    @OutputTempTables bit = 0,
    @LogLevel varchar(10) = 'INFO'
as

set nocount, xact_abort on;
set transaction isolation level read committed;

if @@trancount != 0 throw 50000, N'Open transaction not allowed', 1;
if @@options & 2 != 0 throw 50000, N'Implicit transactions not allowed', 1;

if has_perms_by_name(null, null, 'view any database') != 1
begin
    exec JobRunner.LogWarnV2 @CurrentLogLevel = @LogLevel, @Message = N'Missing server permission "view any database" means "select * from sys.databases" might not include all databases on server';
end

select top 0 cast('' as char(6)) as ChangeType, *
into #MergeOutput
from JobRunner.[Database];

merge JobRunner.[Database] with (serializable, updlock, paglock) t
using (
    select *
    from sys.databases
    where [name] not in (N'master', N'tempdb', N'model', N'msdb')
) s
on s.[name] = t.DatabaseName
when not matched by target then
    insert (DatabaseName)
    values (s.[name])
when matched then
    update
    set
        t.LastSeenDtmUtc = getutcdate(),
        t.IsDeleted = 0,
        t.HardDeletionDtmUtc = null
when not matched by source and t.IsDeleted = 0 then
    update
    set
        t.IsDeleted = 1,
        t.HardDeletionDtmUtc = dateadd(hour, 168, getutcdate())
when not matched by source and t.IsDeleted = 1 and getutcdate() >= t.HardDeletionDtmUtc then
    delete
output
    $action,
    coalesce(inserted.DatabaseName, deleted.DatabaseName) as DatabaseName,
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

if @OutputTempTables = 1
begin
    select * from #MergeOutput;
end

return 0;
