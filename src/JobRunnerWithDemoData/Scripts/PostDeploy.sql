/*
********************
Post-deployment
********************
*/

declare @DatabaseName sysname = db_name();
declare @JobRunnerName sysname = N'Job Runner - ' + @DatabaseName;
declare @CpuIdleJobName sysname = N'Job Runner (Idle CPU) - ' + @DatabaseName;

declare @CategoryName sysname = N'Database Maintenance';
exec JobRunner.EnsureCategoryExists @CategoryName = @CategoryName;

declare @ScheduleNameRecurringInterval sysname = N'Job Runner - Every 10 seconds';
exec JobRunner.EnsureScheduleExists @ScheduleName = @ScheduleNameRecurringInterval, @Mode = 'recurring', @RecurringSecondsInterval = 10, @LogLevel = 'error';

declare @ScheduleNameCpuIdle sysname = N'Job Runner - CPU Idle';
exec JobRunner.EnsureScheduleExists @ScheduleName = @ScheduleNameCpuIdle, @Mode = 'CPUIdle', @LogLevel = 'error';

--exec JobRunner.RegisterAgentJob
--    @JobRunnerName = @JobRunnerName,
--    @ScheduleName = @JobRunnerName,
--    @CategoryName = @CategoryName,
--    @OwnerLoginName = N'sa',
--    @ServerName = N'(local)',
--    @Mode = N'Recurring',
--    @RecurringSecondsInterval = 10,
--    @JobRunnerDescription = N'My job runner';

--exec JobRunner.RegisterAgentJob
--    @JobRunnerName = @CpuIdleJobName,
--    @ScheduleName = @CpuIdleJobName,
--    @CategoryName = @CategoryName,
--    @OwnerLoginName = N'sa',
--    @ServerName = N'(local)',
--    @Mode = N'CPUIdle',
--    @JobRunnerDescription = N'My job runner (CPU idle)';

exec JobRunner.AddAgentJob
    @JobRunnerName = @JobRunnerName,
    @CategoryName = @CategoryName,
    @ScheduleName = @ScheduleNameRecurringInterval,
    @ServerName = N'(local)',
    @DatabaseName = @DatabaseName,
    @OwnerLoginName = N'sa',
    @Mode = N'Recurring',
    @RecurringSecondsInterval = 10,
    @DeleteJobHistory = 1;

exec JobRunner.AddAgentJob
    @JobRunnerName = @CpuIdleJobName,
    @CategoryName = @CategoryName,
    @ScheduleName = @ScheduleNameCpuIdle,
    @ServerName = N'(local)',
    @DatabaseName = @DatabaseName,
    @OwnerLoginName = N'sa',
    @Mode = N'CPUIdle',
    @DeleteJobHistory = 1;


exec JobRunner.AddRunnableProcedure
    @JobRunnerName = @JobRunnerName,
    @SchemaName = N'dbo',
    @ProcedureName = N'NoOpNoParams',
    @IsEnabledOnCreation = 1;

exec JobRunner.AddRunnableProcedure
    @JobRunnerName = @JobRunnerName,
    @SchemaName = N'dbo',
    @ProcedureName = N'NoOpBatchSizeParam',
    @IsEnabledOnCreation = 1;

exec JobRunner.AddRunnableProcedure
    @JobRunnerName = @JobRunnerName,
    @SchemaName = N'dbo',
    @ProcedureName = N'NoOpDoneParam',
    @IsEnabledOnCreation = 1;

exec JobRunner.AddRunnableProcedure
    @JobRunnerName = @JobRunnerName,
    @SchemaName = N'dbo',
    @ProcedureName = N'NoOpDoneParamSetsDoneToTrue',
    @IsEnabledOnCreation = 1;

exec JobRunner.AddRunnableProcedure
    @JobRunnerName = @JobRunnerName,
    @SchemaName = N'dbo',
    @ProcedureName = N'NoOpBatchSizeAndDoneParam',
    @IsEnabledOnCreation = 1;

exec JobRunner.AddRunnableProcedure
    @JobRunnerName = @JobRunnerName,
    @SchemaName = N'dbo',
    @ProcedureName = N'NoOpNoParamsSlow',
    @IsEnabledOnCreation = 1;

exec JobRunner.AddRunnableProcedure
    @JobRunnerName = @JobRunnerName,
    @SchemaName = N'dbo',
    @ProcedureName = N'NoOpNoParamsReturnCodeNonZero',
    @IsEnabledOnCreation = 1;

exec JobRunner.AddRunnableProcedure
    @JobRunnerName = @JobRunnerName,
    @SchemaName = N'dbo',
    @ProcedureName = N'NoOpNoParamsThrow',
    @IsEnabledOnCreation = 1;

exec JobRunner.AddRunnableProcedure
    @JobRunnerName = @JobRunnerName,
    @SchemaName = N'dbo',
    @ProcedureName = N'NoOpNoParamsLeavesTransactionOpen',
    @IsEnabledOnCreation = 1;

exec JobRunner.AddRunnableProcedure
    @JobRunnerName = @JobRunnerName,
    @SchemaName = N'dbo',
    @ProcedureName = N'UpdateGuidValJob',
    @IsEnabledOnCreation = 1;

exec JobRunner.AddRunnableProcedure
    @JobRunnerName = @CpuIdleJobName,
    @SchemaName = N'dbo',
    @ProcedureName = N'CpuIdleNoOpWithParams',
    @IsEnabledOnCreation = 1;

/*
Bypass JobRunner.AddRunnableProcedure to insert a non-existent procedure into
the database.
This would ordinarily produce an error at SqlPackage.exe deployment time.
This test is just here to prove that the procedure being missing at runtime
leads to an appropriate error being raised and correctly handled.
*/
merge JobRunner.RunnableProcedure with (serializable, updlock, rowlock) t
using (
    select
        @JobRunnerName as JobRunnerName,
        N'dbo' as SchemaName,
        N'ProcedureThatDoesNotExist' as ProcedureName,
        GeneratedProcedureWrapperSql = N'
create or alter procedure [#JobRunnerWrapper]
    @BatchSize int,
    @Done bit output
as
declare @Result int = 0;
exec @Result = [dbo].[ProcedureThatDoesNotExist];
return @Result;
'
) s
on
    t.JobRunnerName = s.JobRunnerName and
    t.SchemaName = s.SchemaName and
    t.ProcedureName = s.ProcedureName
when matched then
    update
    set
        t.IsEnabled = 1,
        t.HasIndicatedDone = 0,
        t.LastElapsedMilliseconds = 0,
        t.AttemptedExecutionCount = 0,
        t.SuccessfulExecutionCount = 0,
        t.ExecutionFailedViolationCount = 0,
        t.ExecutionTimeViolationCount = 0,
        t.ErrorNumber = 0,
        t.ErrorMessage = N'',
        t.ErrorLine = 0,
        t.ErrorProcedure = N'',
        t.ErrorSeverity = 0,
        t.ErrorState = 0,
        t.FailedWhileCreatingWrapperProcedure = 0,
        t.DoneDtmUtc = '9999-12-31',
        t.LastExecutedDtmUtc = '0001-01-01'
when not matched by target then
    insert (JobRunnerName, SchemaName, ProcedureName, IsEnabled, GeneratedProcedureWrapperSql)
    values (s.JobRunnerName, s.SchemaName, s.ProcedureName, 1, s.GeneratedProcedureWrapperSql);


/*
Create some rows in dbo.GuidVal so that the nullable
LastUpdatedDtmUtc column can be backfilled
*/
truncate table dbo.GuidVal;
insert into dbo.GuidVal (Val)
select top 2000 newid() from sys.all_columns;
