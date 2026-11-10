// Power Query (M): load downtime_clean.csv and set types
let
    Source  = Csv.Document(File.Contents(ProjectFolder & "data\clean\downtime_clean.csv"),
                [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    Headers = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    Blanks  = Table.ReplaceValue(Headers, "", null, Replacer.ReplaceValue, Table.ColumnNames(Headers)),
    Typed   = Table.TransformColumnTypes(Blanks, {
                {"event_id", type text}, {"bioreactor", type text}, {"date", type date},
                {"category", type text}, {"cause", type text}, {"hours", type number},
                {"month", type date}}, "en-US")
in
    Typed
