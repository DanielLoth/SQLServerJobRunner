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

merge JobRunner.Config with (serializable, updlock) t
using (
    select
        @JobRunnerName as JobRunnerName,
        30000 as TargetJobRunnerExecTimeMilliseconds,
        1000 as BatchSize,
        -5 as DeadlockPriority,
        3000 as LockTimeoutMilliseconds,
        1000 as MaxSyncSecondaryCommitLatencyMilliseconds,
        5000 as MaxAsyncSecondaryCommitLatencyMilliseconds,
        300 as MaxSyncSecondaryRedoQueueSize,
        5000 as MaxAsyncSecondaryRedoQueueSize,
        5 as MaxProcedureExecTimeViolationCount,
        500 as MaxProcedureExecTimeMilliseconds,
        500 as BatchSleepMilliseconds
    union all
    select
        @CpuIdleJobName as JobRunnerName,
        3000 as TargetJobRunnerExecTimeMilliseconds,
        1000 as BatchSize,
        -5 as DeadlockPriority,
        3000 as LockTimeoutMilliseconds,
        1000 as MaxSyncSecondaryCommitLatencyMilliseconds,
        5000 as MaxAsyncSecondaryCommitLatencyMilliseconds,
        300 as MaxSyncSecondaryRedoQueueSize,
        5000 as MaxAsyncSecondaryRedoQueueSize,
        5 as MaxProcedureExecTimeViolationCount,
        10000 as MaxProcedureExecTimeMilliseconds,
        1000 as BatchSleepMilliseconds
) s
on t.JobRunnerName = s.JobRunnerName
when matched then
    update
    set
        t.TargetJobRunnerExecTimeMilliseconds = s.TargetJobRunnerExecTimeMilliseconds,
        t.BatchSize = s.BatchSize,
        t.DeadlockPriority = s.DeadlockPriority,
        t.LockTimeoutMilliseconds = s.LockTimeoutMilliseconds,
        t.MaxSyncSecondaryCommitLatencyMilliseconds = s.MaxSyncSecondaryCommitLatencyMilliseconds,
        t.MaxAsyncSecondaryCommitLatencyMilliseconds = s.MaxAsyncSecondaryCommitLatencyMilliseconds,
        t.MaxSyncSecondaryRedoQueueSize = s.MaxSyncSecondaryRedoQueueSize,
        t.MaxAsyncSecondaryRedoQueueSize = s.MaxAsyncSecondaryRedoQueueSize,
        t.MaxProcedureExecTimeViolationCount = s.MaxProcedureExecTimeViolationCount,
        t.MaxProcedureExecTimeMilliseconds = s.MaxProcedureExecTimeMilliseconds,
        t.BatchSleepMilliseconds = s.BatchSleepMilliseconds
when not matched by target then
    insert (
        JobRunnerName,
        TargetJobRunnerExecTimeMilliseconds,
        BatchSize,
        DeadlockPriority,
        LockTimeoutMilliseconds,
        MaxSyncSecondaryCommitLatencyMilliseconds,
        MaxAsyncSecondaryCommitLatencyMilliseconds,
        MaxSyncSecondaryRedoQueueSize,
        MaxAsyncSecondaryRedoQueueSize,
        MaxProcedureExecTimeViolationCount,
        MaxProcedureExecTimeMilliseconds,
        BatchSleepMilliseconds
    )
    values (
        JobRunnerName,
        TargetJobRunnerExecTimeMilliseconds,
        BatchSize,
        DeadlockPriority,
        LockTimeoutMilliseconds,
        MaxSyncSecondaryCommitLatencyMilliseconds,
        MaxAsyncSecondaryCommitLatencyMilliseconds,
        MaxSyncSecondaryRedoQueueSize,
        MaxAsyncSecondaryRedoQueueSize,
        MaxProcedureExecTimeViolationCount,
        MaxProcedureExecTimeMilliseconds,
        BatchSleepMilliseconds
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
    @IsEnabled = 1;

exec JobRunner.AddRunnableProcedure
    @JobRunnerName = @JobRunnerName,
    @SchemaName = N'dbo',
    @ProcedureName = N'NoOpBatchSizeParam',
    @IsEnabled = 1;

exec JobRunner.AddRunnableProcedure
    @JobRunnerName = @JobRunnerName,
    @SchemaName = N'dbo',
    @ProcedureName = N'NoOpDoneParam',
    @IsEnabled = 1;

exec JobRunner.AddRunnableProcedure
    @JobRunnerName = @JobRunnerName,
    @SchemaName = N'dbo',
    @ProcedureName = N'NoOpBatchSizeAndDoneParam',
    @IsEnabled = 1;

exec JobRunner.AddRunnableProcedure
    @JobRunnerName = @JobRunnerName,
    @SchemaName = N'dbo',
    @ProcedureName = N'NoOpNoParamsSlow',
    @IsEnabled = 1;

exec JobRunner.AddRunnableProcedure
    @JobRunnerName = @JobRunnerName,
    @SchemaName = N'dbo',
    @ProcedureName = N'NoOpNoParamsReturnCodeNonZero',
    @IsEnabled = 1;

exec JobRunner.AddRunnableProcedure
    @JobRunnerName = @JobRunnerName,
    @SchemaName = N'dbo',
    @ProcedureName = N'NoOpNoParamsThrow',
    @IsEnabled = 1;

exec JobRunner.AddRunnableProcedure
    @JobRunnerName = @JobRunnerName,
    @SchemaName = N'dbo',
    @ProcedureName = N'UpdateGuidValJob',
    @IsEnabled = 1;

exec JobRunner.AddRunnableProcedure
    @JobRunnerName = @CpuIdleJobName,
    @SchemaName = N'dbo',
    @ProcedureName = N'CpuIdleNoOpWithParams',
    @IsEnabled = 1;
