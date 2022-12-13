restore database AdventureWorks
from disk = N'/sql-shared/backups/AdventureWorksLT2019.bak'
with file = 1,
move N'AdventureWorksLT2012_Data' to N'/var/opt/mssql/data/AdventureWorksLT2012.mdf',
move N'AdventureWorksLT2012_Log' to N'/var/opt/mssql/data/AdventureWorksLT2012_log.ldf',
nounload, replace, stats = 5;
go

alter database AdventureWorks set recovery full;
go

alter availability group [$(HADR_AG_NAME)] add database AdventureWorks;
go
