// Power Query (M): load batches_clean.csv, set types, add Quarter and Run-length band
// Needs a text parameter named ProjectFolder, e.g. C:\Users\antho\Documents\fujifilm-kpi-lite\
let
    Source   = Csv.Document(File.Contents(ProjectFolder & "data\clean\batches_clean.csv"),
                 [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    Headers  = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    // Empty cells -> null, so numbers and TRUE/FALSE columns type cleanly
    Blanks   = Table.ReplaceValue(Headers, "", null, Replacer.ReplaceValue, Table.ColumnNames(Headers)),
    Typed    = Table.TransformColumnTypes(Blanks, {
                 {"batch_id", type text}, {"product", type text}, {"bioreactor", type text},
                 {"start_date", type date}, {"end_date", type date},
                 {"target_titer_g_L", type number}, {"actual_titer_g_L", type number},
                 {"harvest_volume_L", Int64.Type}, {"purified_kg", type number},
                 {"deviations", Int64.Type}, {"status", type text},
                 {"qa_release_date", type date}, {"promised_date", type date}, {"delivered_date", type date},
                 {"electricity_kwh", type number}, {"is_success", type logical}, {"is_rft", type logical},
                 {"titer_vs_target", type number}, {"run_days", Int64.Type}, {"qa_lead_days", Int64.Type},
                 {"on_time", type logical}, {"electricity_source", type text},
                 {"co2e_kg", type number}, {"kwh_per_kg", type number}, {"month", type date}}, "en-US"),
    Quarter  = Table.AddColumn(Typed, "quarter",
                 each Text.From(Date.Year([end_date])) & "-Q" & Text.From(Date.QuarterOfYear([end_date])), type text),
    RunBand  = Table.AddColumn(Quarter, "run_length_band",
                 each if [run_days] <= 16 then "Standard (<=16 d)"
                      else if [run_days] <= 17 then "Slightly long (17 d)"
                      else "Long (18+ d)", type text)
in
    RunBand
