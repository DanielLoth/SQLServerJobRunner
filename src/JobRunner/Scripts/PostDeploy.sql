/*
********************
Post-deployment
********************
*/

declare @DatabaseName sysname = db_name();
declare @JobRunnerName sysname = N'Job Runner - ' + @DatabaseName;
declare @CpuIdleJobName sysname = N'Job Runner (Idle CPU) - ' + @DatabaseName;

/* Use a valid category name here */
declare @CategoryName sysname = N'Database Maintenance';

exec JobRunner.AddAgentJob
	@JobRunnerName = @JobRunnerName,
	@CategoryName = @CategoryName,
	@ServerName = N'(local)',
	@DatabaseName = @DatabaseName,
	@OwnerLoginName = N'sa',
	@Mode = N'Recurring',
	@RecurringSecondsInterval = 10,
	@DeleteJobHistory = 1;

exec JobRunner.AddAgentJob
	@JobRunnerName = @CpuIdleJobName,
	@CategoryName = @CategoryName,
	@ServerName = N'(local)',
	@DatabaseName = @DatabaseName,
	@OwnerLoginName = N'sa',
	@Mode = N'CPUIdle',
	@DeleteJobHistory = 1;
