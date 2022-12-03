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

exec JobRunner.RegisterAgentJob
    @JobRunnerName = @JobRunnerName,
    @ScheduleName = @JobRunnerName,
    @CategoryName = @CategoryName,
    @OwnerLoginName = N'sa',
    @ServerName = N'(local)',
    @Mode = N'Recurring',
    @RecurringSecondsInterval = 10,
    @JobRunnerDescription = N'My job runner';

exec JobRunner.RegisterAgentJob
    @JobRunnerName = @CpuIdleJobName,
    @ScheduleName = @CpuIdleJobName,
    @CategoryName = @CategoryName,
    @OwnerLoginName = N'sa',
    @ServerName = N'(local)',
    @Mode = N'CPUIdle',
    @JobRunnerDescription = N'My job runner (CPU idle)';

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
