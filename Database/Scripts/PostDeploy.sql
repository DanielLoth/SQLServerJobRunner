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

/* Use a valid category name here */
declare @CategoryName sysname = N'Database Maintenance';

exec JobRunner.AddAgentJob
    @JobName = @JobName,
    @CategoryName = @CategoryName,
    @ServerName = '(local)',
    @DatabaseName = @DatabaseName,
    @OwnerLoginName = N'sa',
    @Mode = 'Recurring',
    @RecurringSecondsInterval = 10;

--declare @CpuIdleJobName sysname = N'Job Runner (Idle CPU) - ' + @DatabaseName;

--exec JobRunner.AddAgentJob
--    @JobName = @CpuIdleJobName,
--    @CategoryName = @CategoryName,
--    @ServerName = '(local)',
--    @DatabaseName = @DatabaseName,
--    @OwnerLoginName = N'sa',
--    @Mode = 'CPUIdle';
