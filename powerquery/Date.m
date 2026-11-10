// Power Query (M): Date table built in M (Blank Query -> Advanced Editor -> paste)
let
    StartDate = #date(2025, 1, 1),
    EndDate   = #date(2026, 12, 31),
    Dates     = List.Dates(StartDate, Duration.Days(EndDate - StartDate) + 1, #duration(1, 0, 0, 0)),
    AsTable   = Table.FromList(Dates, Splitter.SplitByNothing(), {"Date"}),
    Typed     = Table.TransformColumnTypes(AsTable, {{"Date", type date}}),
    Year      = Table.AddColumn(Typed, "Year", each Date.Year([Date]), Int64.Type),
    Quarter   = Table.AddColumn(Year, "Quarter",
                  each Text.From(Date.Year([Date])) & "-Q" & Text.From(Date.QuarterOfYear([Date])), type text),
    Month     = Table.AddColumn(Quarter, "Month", each Date.StartOfMonth([Date]), type date),
    MonthName = Table.AddColumn(Month, "Month Name", each Date.ToText([Date], "MMM yyyy", "en-US"), type text),
    MonthSort = Table.AddColumn(MonthName, "Month Sort", each Date.Year([Date]) * 100 + Date.Month([Date]), Int64.Type)
in
    MonthSort
