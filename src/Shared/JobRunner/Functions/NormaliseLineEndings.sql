create function JobRunner.NormaliseLineEndings (
    @Value nvarchar(max)
)
returns nvarchar(max)
as
begin
    declare @Cr char(1) = char(13);
    declare @Lf char(1) = char(10);
    declare @CrLf char(2) = @Cr + @Lf;

    set @Value = replace(@Value, @CrLf, '##CRLF##');
    set @Value = replace(@Value, @Cr, @CrLf);
    set @Value = replace(@Value, @Lf, @CrLf);
    set @Value = replace(@Value, '##CRLF##', @CrLf);

    return @Value;
end

go
