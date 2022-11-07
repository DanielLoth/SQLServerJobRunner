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
