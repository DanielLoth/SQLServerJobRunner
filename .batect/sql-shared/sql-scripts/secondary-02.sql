alter availability group [$(HADR_AG_NAME)] join with (cluster_type = none);
alter availability group [$(HADR_AG_NAME)] grant create any database;
go
