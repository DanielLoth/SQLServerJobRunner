/*
Post-Deployment Script Template							
--------------------------------------------------------------------------------------
 This file contains SQL statements that will be appended to the build script.		
 Use SQLCMD syntax to include a file in the post-deployment script.			
 Example:      :r .\myfile.sql								
 Use SQLCMD syntax to reference a variable in the post-deployment script.		
 Example:      :setvar TableName MyTable							
               SELECT * FROM [$(TableName)]					
--------------------------------------------------------------------------------------
*/

declare @DatabaseName sysname = db_name();
declare @JobRunnerName sysname = N'Job Runner - ' + @DatabaseName;
declare @CpuIdleJobName sysname = N'Job Runner (Idle CPU) - ' + @DatabaseName;

/* Use a valid category name here */
declare @CategoryName sysname = N'Database Maintenance';

declare @JobConfig table (
	JobRunnerName sysname not null,
	TargetJobRunnerExecTimeMilliseconds int not null,
	[BatchSize] int not null,
	DeadlockPriority int not null,
	LockTimeoutMilliseconds int not null,
	MaxSyncSecondaryCommitLatencyMilliseconds bigint not null,
	MaxAsyncSecondaryCommitLatencyMilliseconds bigint not null,
	MaxSyncSecondaryRedoQueueSize bigint not null,
	MaxAsyncSecondaryRedoQueueSize bigint not null,
	MaxProcedureExecutionTimeViolationCount int not null,
	MaxProcedureExecutionTimeMilliseconds int not null,
	BatchSleepMilliseconds int not null,
    ResetViolationCountToZeroOnDeploy bit not null,
    ResetDoneFlagToFalseOnDeploy bit not null,
    ResetEnabledFlagToTrueOnDeploy bit not null,
    ResetErrorColumnsOnDeploy bit not null,
    ResetExecutionCountersOnDeploy bit not null,

    primary key (JobRunnerName)
);

insert into @JobConfig (
    JobRunnerName,
    TargetJobRunnerExecTimeMilliseconds,
    [BatchSize],
    DeadlockPriority,
    LockTimeoutMilliseconds,
    MaxSyncSecondaryCommitLatencyMilliseconds,
    MaxAsyncSecondaryCommitLatencyMilliseconds,
    MaxSyncSecondaryRedoQueueSize,
    MaxAsyncSecondaryRedoQueueSize,
    MaxProcedureExecutionTimeViolationCount,
    MaxProcedureExecutionTimeMilliseconds,
    BatchSleepMilliseconds,
    ResetViolationCountToZeroOnDeploy,
    ResetDoneFlagToFalseOnDeploy,
    ResetEnabledFlagToTrueOnDeploy,
    ResetErrorColumnsOnDeploy,
    ResetExecutionCountersOnDeploy
)
values
    (@JobRunnerName, 30000, 1000, -5, 3000, 1000, 5000, 300, 5000, 5, 500, 500, 1, 1, 1, 1, 1),
    (@CpuIdleJobName, 30000, 1000, -5, 3000, 1000, 5000, 300, 5000, 5, 10000, 1000, 1, 1, 1, 1, 1);

merge JobRunner.Config with (serializable, updlock) t
using @JobConfig s
on t.JobRunnerName = s.JobRunnerName
when matched then
    update
    set
        t.TargetJobRunnerExecTimeMilliseconds = s.TargetJobRunnerExecTimeMilliseconds,
        t.[BatchSize] = s.[BatchSize],
        t.DeadlockPriority = s.DeadlockPriority,
        t.LockTimeoutMilliseconds = s.LockTimeoutMilliseconds,
        t.MaxSyncSecondaryCommitLatencyMilliseconds = s.MaxSyncSecondaryCommitLatencyMilliseconds,
        t.MaxAsyncSecondaryCommitLatencyMilliseconds = s.MaxAsyncSecondaryCommitLatencyMilliseconds,
        t.MaxSyncSecondaryRedoQueueSize = s.MaxSyncSecondaryRedoQueueSize,
        t.MaxAsyncSecondaryRedoQueueSize = s.MaxAsyncSecondaryRedoQueueSize,
        t.MaxProcedureExecutionTimeViolationCount = s.MaxProcedureExecutionTimeViolationCount,
        t.MaxProcedureExecutionTimeMilliseconds = s.MaxProcedureExecutionTimeMilliseconds,
        t.BatchSleepMilliseconds = s.BatchSleepMilliseconds,
        t.ResetViolationCountToZeroOnDeploy = s.ResetViolationCountToZeroOnDeploy,
        t.ResetDoneFlagToFalseOnDeploy = s.ResetDoneFlagToFalseOnDeploy,
        t.ResetEnabledFlagToTrueOnDeploy = s.ResetEnabledFlagToTrueOnDeploy,
        t.ResetErrorColumnsOnDeploy = s.ResetErrorColumnsOnDeploy,
        t.ResetExecutionCountersOnDeploy = s.ResetExecutionCountersOnDeploy
when not matched by target then
    insert (
        JobRunnerName,
        TargetJobRunnerExecTimeMilliseconds,
        [BatchSize],
        DeadlockPriority,
        LockTimeoutMilliseconds,
        MaxSyncSecondaryCommitLatencyMilliseconds,
        MaxAsyncSecondaryCommitLatencyMilliseconds,
        MaxSyncSecondaryRedoQueueSize,
        MaxAsyncSecondaryRedoQueueSize,
        MaxProcedureExecutionTimeViolationCount,
        MaxProcedureExecutionTimeMilliseconds,
        BatchSleepMilliseconds,
        ResetViolationCountToZeroOnDeploy,
        ResetDoneFlagToFalseOnDeploy,
        ResetEnabledFlagToTrueOnDeploy,
        ResetErrorColumnsOnDeploy,
        ResetExecutionCountersOnDeploy
    )
    values (
        JobRunnerName,
        TargetJobRunnerExecTimeMilliseconds,
        [BatchSize],
        DeadlockPriority,
        LockTimeoutMilliseconds,
        MaxSyncSecondaryCommitLatencyMilliseconds,
        MaxAsyncSecondaryCommitLatencyMilliseconds,
        MaxSyncSecondaryRedoQueueSize,
        MaxAsyncSecondaryRedoQueueSize,
        MaxProcedureExecutionTimeViolationCount,
        MaxProcedureExecutionTimeMilliseconds,
        BatchSleepMilliseconds,
        ResetViolationCountToZeroOnDeploy,
        ResetDoneFlagToFalseOnDeploy,
        ResetEnabledFlagToTrueOnDeploy,
        ResetErrorColumnsOnDeploy,
        ResetExecutionCountersOnDeploy
    )
when not matched by source then
    delete;



exec JobRunner.AddAgentJob
    @JobRunnerName = @JobRunnerName,
    @CategoryName = @CategoryName,
    @ServerName = N'(local)',
    @DatabaseName = @DatabaseName,
    @OwnerLoginName = N'sa',
    @Mode = N'Recurring',
    @RecurringSecondsInterval = 10;

exec JobRunner.AddAgentJob
    @JobRunnerName = @CpuIdleJobName,
    @CategoryName = @CategoryName,
    @ServerName = N'(local)',
    @DatabaseName = @DatabaseName,
    @OwnerLoginName = N'sa',
    @Mode = N'CPUIdle';

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
        t.FailedExecutionCount = 0,
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
