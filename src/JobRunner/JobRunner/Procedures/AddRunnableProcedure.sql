create procedure JobRunner.AddRunnableProcedure
    @JobRunnerName sysname,
    @SchemaName sysname,
    @ProcedureName sysname,
    @IsEnabledOnCreation bit
as

set nocount, xact_abort on;
set transaction isolation level read committed;

if @@trancount != 0 throw 50000, N'Open transaction not allowed', 1;
if @@options & 2 != 0 throw 50000, N'Implicit transactions not allowed', 1;

declare
    @HasBatchSizeParam bit,
    @HasDoneParam bit,
    @HasExtraParam bit,
    @ResetIsEnabled bit,
    @ResetDoneFlag bit,
    @ResetViolationCount bit,
    @Sql nvarchar(4000),
    @Msg nvarchar(2000);

if not exists (
    select 1
    from sys.procedures
    where
        object_schema_name(object_id) = @SchemaName and
        object_name(object_id) = @ProcedureName
)
begin
    set @Msg = N'Procedure "' + @SchemaName + N'.' + @ProcedureName + N'" does not exist';
    throw 50000, @Msg, 1;
end

select
    @HasBatchSizeParam = d.HasBatchSizeParam,
    @HasDoneParam = d.HasDoneParam,
    @HasExtraParam = d.HasExtraParam
from sys.procedures p
outer apply (
    select 1 as BatchSizeParam
    from sys.parameters p1
    where
        p.object_id = p1.object_id and
        p1.name = N'@BatchSize' and
        p1.user_type_id = 56 /* 56 = int */
) d1
outer apply (
    select 1 as DoneParam
    from sys.parameters p1
    where
        p.object_id = p1.object_id and
        p1.name = N'@Done'
        and p1.is_output = 1
        and p1.user_type_id = 104 /* 104 = bit */
) d2
outer apply (
    select 1 as ExtraParam
    from sys.parameters p1
    where
        p.object_id = p1.object_id and
        p1.name not in (N'@BatchSize', N'@Done')
) d3
outer apply (
    select
        isnull(cast(d1.BatchSizeParam as bit), 0) as HasBatchSizeParam,
        isnull(cast(d2.DoneParam as bit), 0) as HasDoneParam,
        isnull(cast(d3.ExtraParam as bit), 0) as HasExtraParam
) d
where
    object_schema_name(p.object_id) = @SchemaName and
    object_name(p.object_id) = @ProcedureName;

if @HasExtraParam = 1
begin
    set @Msg =
        N'Procedure "' + @SchemaName + N'.' + @ProcedureName +
        N'" has unsupported parameters. Only the following ' +
        N'parameters are supported: @BatchSize int, @Done bit output';

    throw 50000, @Msg, 1;
end

exec JobRunner.GetRunnableProcedure
    @JobRunnerName = @JobRunnerName,
    @SchemaName = @SchemaName,
    @ProcedureName = @ProcedureName,
    @HasBatchSizeParam = @HasBatchSizeParam,
    @HasDoneParam = @HasDoneParam,
    @GeneratedProcedureSql = @Sql output;

merge JobRunner.RunnableProcedure with (serializable, updlock, rowlock) t
using (
    select
        s.*,
        c.ResetViolationCountToZeroOnDeploy,
        c.ResetDoneFlagToFalseOnDeploy,
        c.ResetEnabledFlagToTrueOnDeploy,
        c.ResetErrorColumnsOnDeploy,
        c.ResetExecutionCountersOnDeploy
    from (
        select
            @JobRunnerName as JobRunnerName,
            @SchemaName as SchemaName,
            @ProcedureName as ProcedureName,
            @IsEnabledOnCreation as IsEnabled,
            @Sql as GeneratedProcedureWrapperSql
    ) s
    inner join JobRunner.Config c on s.JobRunnerName = c.JobRunnerName
) s
on
    t.JobRunnerName = s.JobRunnerName and
    t.SchemaName = s.SchemaName and
    t.ProcedureName = s.ProcedureName
when matched then
    update
    set
        /* Enabled flag reset */
        t.IsEnabled =
            case
                when s.ResetEnabledFlagToTrueOnDeploy = 1 then 1
                else t.IsEnabled
            end,

        /* Done flag, and done datetime2 column, reset */
        t.HasIndicatedDone =
            case
                when s.ResetDoneFlagToFalseOnDeploy = 1 then 0
                else t.HasIndicatedDone
            end,
        t.DoneDtmUtc =
            case
                when s.ResetDoneFlagToFalseOnDeploy = 1 then '9999-12-31'
                else t.DoneDtmUtc
            end,

        /*t.LastElapsedMilliseconds = 0, */ /* Probably don't need to reset this */

        /* Execution counter reset */
        t.AttemptedExecutionCount =
            case
                when ResetExecutionCountersOnDeploy = 1 then 0
                else t.AttemptedExecutionCount
            end,
        t.SuccessfulExecutionCount =
            case
                when ResetExecutionCountersOnDeploy = 1 then 0
                else t.SuccessfulExecutionCount
            end,

        /* Violation count reset */
        t.ExecutionFailedViolationCount =
            case
                when ResetViolationCountToZeroOnDeploy = 1 then 0
                else t.ExecutionFailedViolationCount
            end,
        t.ExecutionTimeViolationCount =
            case
                when s.ResetViolationCountToZeroOnDeploy = 1 then 0
                else t.ExecutionTimeViolationCount
            end,

        /* Error column reset */
        t.ErrorNumber =
            case
                when s.ResetErrorColumnsOnDeploy = 1 then 0
                else t.ErrorNumber
            end,
        t.ErrorMessage =
            case
                when s.ResetErrorColumnsOnDeploy = 1 then N''
                else t.ErrorMessage
            end,
        t.ErrorLine =
            case
                when s.ResetErrorColumnsOnDeploy = 1 then 0
                else t.ErrorLine
            end,
        t.ErrorProcedure =
            case
                when s.ResetErrorColumnsOnDeploy = 1 then N''
                else t.ErrorProcedure
            end,
        t.ErrorSeverity =
            case
                when s.ResetErrorColumnsOnDeploy = 1 then 0
                else t.ErrorSeverity
            end,
        t.ErrorState =
            case
                when s.ResetErrorColumnsOnDeploy = 1 then 0
                else t.ErrorState
            end,

        t.GeneratedProcedureWrapperSql = s.GeneratedProcedureWrapperSql,
        t.FailedWhileCreatingWrapperProcedure = 0
when not matched by target then
    insert (JobRunnerName, SchemaName, ProcedureName, IsEnabled, GeneratedProcedureWrapperSql)
    values (s.JobRunnerName, s.SchemaName, s.ProcedureName, s.IsEnabled, s.GeneratedProcedureWrapperSql);

return 0;

go
