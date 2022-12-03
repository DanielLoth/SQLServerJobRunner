create procedure JobRunner.RegisterAgentJob
    @JobRunnerName sysname,
    @ScheduleName sysname,
    @CategoryName sysname,
    @OwnerLoginName sysname = N'sa',
    @ServerName sysname = N'(local)',
    @Mode nvarchar(20) = N'Recurring',
    @RecurringSecondsInterval int = 10,
    @JobRunnerDescription nvarchar(512) = N''
as

set nocount, xact_abort on;
set transaction isolation level read committed;

if @@trancount != 0 throw 50000, N'Open transaction not allowed', 1;
if @@options & 2 != 0 throw 50000, N'Implicit transactions not allowed', 1;

if @Mode = N'CPUIdle' set @RecurringSecondsInterval = 0;

merge JobRunner.Config with (updlock, paglock, serializable) t
using (
    select
        @JobRunnerName as JobRunnerName,
        @ScheduleName as ScheduleName,
        @CategoryName as CategoryName,
        @OwnerLoginName as OwnerLoginName,
        @ServerName as ServerName,
        @Mode as Mode,
        @RecurringSecondsInterval as RecurringSecondsInterval,
        @JobRunnerDescription as JobRunnerDescription
) s
on t.JobRunnerName = s.JobRunnerName
when not matched by target then
    insert (JobRunnerName, ScheduleName, CategoryName, OwnerLoginName, ServerName, Mode, RecurringSecondsInterval, JobRunnerDescription)
    values (s.JobRunnerName, s.ScheduleName, s.CategoryName, s.OwnerLoginName, s.ServerName, s.Mode, s.RecurringSecondsInterval, s.JobRunnerDescription)
when matched then
    update
    set
        t.ScheduleName = s.ScheduleName,
        t.CategoryName = s.CategoryName,
        t.OwnerLoginName = s.OwnerLoginName,
        t.ServerName = s.ServerName,
        t.Mode = s.Mode,
        t.RecurringSecondsInterval = s.RecurringSecondsInterval,
        t.JobRunnerDescription = s.JobRunnerDescription;

return 0;
