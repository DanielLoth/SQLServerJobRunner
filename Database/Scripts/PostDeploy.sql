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

exec JobRunner.AddAgentJob
    @JobNamePrefix = N'Job Runner - ',
    @CategoryName = N'Database Maintenance',
    @ServerName = '(local)',
    @DatabaseName = @DatabaseName,
    @OwnerLoginName = N'sa';
