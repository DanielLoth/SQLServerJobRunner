create procedure dbo.NoOpNoParams
as
set nocount, xact_abort on;
select 1 as A;
return 0;

go

create procedure dbo.NoOpBatchSizeParam
	@BatchSize int
as
set nocount, xact_abort on;
select 1 as A;
return 0;

go

create procedure dbo.NoOpDoneParam
	@Done bit output
as
set nocount, xact_abort on;
select 1 as A;
return 0;

go

create procedure dbo.NoOpBatchSizeAndDoneParam
	@BatchSize int,
	@Done bit output
as
set nocount, xact_abort on;
select 1 as A;
return 0;

go

create procedure dbo.NoOpNoParamsSlow
as
set nocount, xact_abort on;
select 1 as A;
waitfor delay '00:00:01';
return 0;

go

create procedure dbo.NoOpNoParamsReturnCodeNonZero
as
set nocount, xact_abort on;
return 1;

go

create procedure dbo.NoOpNoParamsThrow
as
set nocount, xact_abort on;
if 1=1 throw 133337, N'Something went wrong...', 1;
return 0;

go
