// Power Query (M): a Group By summary built FROM the downtime_clean query
// (shows Reference + Group By; use it for a cause x bioreactor matrix)
let
    Source  = downtime_clean,
    Unplan  = Table.SelectRows(Source, each [category] = "Unplanned"),
    Grouped = Table.Group(Unplan, {"bioreactor", "cause"}, {
                {"events", each Table.RowCount(_), Int64.Type},
                {"hours",  each List.Sum([hours]), type number}}),
    Sorted  = Table.Sort(Grouped, {{"hours", Order.Descending}})
in
    Sorted
