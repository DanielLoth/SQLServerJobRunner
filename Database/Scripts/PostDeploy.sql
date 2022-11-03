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
declare @JobName sysname = N'Job Runner - ' + @DatabaseName;
declare @CpuIdleJobName sysname = N'Job Runner (Idle CPU) - ' + @DatabaseName;

/* Use a valid category name here */
declare @CategoryName sysname = N'Database Maintenance';

merge JobRunner.Config with (serializable, updlock) t
using (
    select
        @JobName as JobRunnerName,
        30000 as TargetJobRunnerExecTimeMilliseconds,
        1000 as NumRowsPerBatch,
        -5 as DeadlockPriority,
        3000 as LockTimeoutMilliseconds,
        3000 as MaxCommitLatencyMilliseconds,
        300 as MaxRedoQueueSize,
        5 as MaxProcedureExecTimeViolationCount,
        10000 as MaxProcedureExecTimeMilliseconds,
        '00:00:00.500' as BatchSleepTime
    union all
    select
        @CpuIdleJobName as JobRunnerName,
        30000 as TargetJobRunnerExecTimeMilliseconds,
        1000 as NumRowsPerBatch,
        -5 as DeadlockPriority,
        3000 as LockTimeoutMilliseconds,
        3000 as MaxCommitLatencyMilliseconds,
        300 as MaxRedoQueueSize,
        5 as MaxProcedureExecTimeViolationCount,
        10000 as MaxProcedureExecTimeMilliseconds,
        '00:00:00.500' as BatchSleepTime
) s
on t.JobRunnerName = s.JobRunnerName
when matched then
    update
    set
        t.TargetJobRunnerExecTimeMilliseconds = s.TargetJobRunnerExecTimeMilliseconds,
        t.NumRowsPerBatch = s.NumRowsPerBatch,
        t.DeadlockPriority = s.DeadlockPriority,
        t.LockTimeoutMilliseconds = s.LockTimeoutMilliseconds,
        t.MaxCommitLatencyMilliseconds = s.MaxCommitLatencyMilliseconds,
        t.MaxRedoQueueSize = s.MaxRedoQueueSize,
        t.MaxProcedureExecTimeViolationCount = s.MaxProcedureExecTimeViolationCount,
        t.MaxProcedureExecTimeMilliseconds = s.MaxProcedureExecTimeMilliseconds,
        t.BatchSleepTime = s.BatchSleepTime
when not matched by target then
    insert (
        JobRunnerName,
        TargetJobRunnerExecTimeMilliseconds,
        NumRowsPerBatch,
        DeadlockPriority,
        LockTimeoutMilliseconds,
        MaxCommitLatencyMilliseconds,
        MaxRedoQueueSize,
        MaxProcedureExecTimeViolationCount,
        MaxProcedureExecTimeMilliseconds,
        BatchSleepTime
    )
    values (
        JobRunnerName,
        TargetJobRunnerExecTimeMilliseconds,
        NumRowsPerBatch,
        DeadlockPriority,
        LockTimeoutMilliseconds,
        MaxCommitLatencyMilliseconds,
        MaxRedoQueueSize,
        MaxProcedureExecTimeViolationCount,
        MaxProcedureExecTimeMilliseconds,
        BatchSleepTime
    )
when not matched by source then
    delete;



exec JobRunner.AddAgentJob
    @JobName = @JobName,
    @CategoryName = @CategoryName,
    @ServerName = '(local)',
    @DatabaseName = @DatabaseName,
    @OwnerLoginName = N'sa',
    @Mode = 'Recurring',
    @RecurringSecondsInterval = 10;

exec JobRunner.AddAgentJob
    @JobName = @CpuIdleJobName,
    @CategoryName = @CategoryName,
    @ServerName = '(local)',
    @DatabaseName = @DatabaseName,
    @OwnerLoginName = N'sa',
    @Mode = 'CPUIdle';
