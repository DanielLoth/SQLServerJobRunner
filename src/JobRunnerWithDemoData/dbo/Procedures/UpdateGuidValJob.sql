create procedure dbo.UpdateGuidValJob
as

set nocount, xact_abort on;

with v as (
    select top 5 *
    from dbo.GuidVal
    order by LastUpdatedDtmUtc
)
update v
set Val = newid(), LastUpdatedDtmUtc = getutcdate();

return 0;
