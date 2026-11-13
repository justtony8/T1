# CEE 492 - Project 3: Multinomial Logistic Regression for NBI Bridge Condition
# Run in VS Code's Julia terminal: include("nbi_logistic_regression.jl")
# Install once: import Pkg; Pkg.add(["CSV", "DataFrames", "MLJ", "MLJLinearModels", "CategoricalArrays", "Plots"])
# Keep this script in the same folder as the original NBI .txt file.

using CSV, DataFrames, Statistics, Random, CategoricalArrays, MLJ, Plots

const DATA_FILE = joinpath(@__DIR__, "Selected_Bridges_September_24_2026_03_51_03.txt")
const OUT_DIR = joinpath(@__DIR__, "model_results")
const CLASSES = ["Good", "Fair", "Poor"]
mkpath(OUT_DIR)

# -------------------- STEP 1: Read the actual 18-column NBI export --------------------
@assert isfile(DATA_FILE) "Data file not found: $DATA_FILE. Move the .txt file next to this script."
raw = CSV.read(DATA_FILE, DataFrame;
    quotechar='\'',
    types=Dict("8 - Structure Number" => String,
               "2025 NBI Structure Number" => String),
    missingstring=["", "NA", "N/A"])

# Only keep the reporting years defined in Deliverable 2 (2002--2025).
d = raw[(raw[!, "Year"] .>= 2002) .& (raw[!, "Year"] .<= 2025), :]
rename!(d, Dict(
    "Year" => "year",
    "2025 NBI Structure Number" => "bridge_id",
    "22 - Owner Agency" => "owner",
    "29 - Average Daily Traffic" => "adt",
    "43A - Main Span Material" => "material",
    "43B - Main Span Design" => "design",
    "45 - Number of Spans in Main Unit" => "spans",
    "49 - Structure Length (ft.)" => "length",
    "CAT10 - Bridge Condition" => "condition",
    "Bridge Age (yr)" => "age",
    "CAT29 - Deck Area (sq. ft.)" => "deck_area",
    "48 - Length of Maximum Span (ft.)" => "max_span",
    "109 - Average Daily Truck Traffic (Percent ADT)" => "truck_share",
    "52 - Deck Width - Out to Out (ft.)" => "deck_width",
))

# Never impute the target class. Reject any unexpected labels.
filter!(row -> !ismissing(row.condition) && String(row.condition) in CLASSES, d)
@assert all(.!ismissing.(d.bridge_id)) "Missing group ID: cannot do grouped split."
println("Labeled bridge-year observations: ", nrow(d))
println("Unique bridges: ", length(unique(d.bridge_id)))
println(combine(groupby(d, :condition), nrow => :count))

# -------------------- STEP 2: Split whole bridges (not individual rows) --------------------
# Stratify grouping by each bridge's latest recorded class, as planned in Deliverable 2.
# Seed and ratio follow the report. Without the original split manifest,
# these groups may not exactly match the previously reported row counts.
latest = Dict{String,Tuple{Int,String}}()
for row in eachrow(d)
    id, yr, cls = String(row.bridge_id), Int(row.year), String(row.condition)
    if !haskey(latest, id) || yr >= latest[id][1]
        latest[id] = (yr, cls)
    end
end

rng = MersenneTwister(492)
partition = Dict{String,String}()
for cls in CLASSES
    ids = sort!([id for (id, (_, c)) in latest if c == cls])
    shuffle!(rng, ids)
    n = length(ids)
    ntrain = round(Int, 0.60 * n)
    nvalid = round(Int, 0.20 * n)
    for (i, id) in enumerate(ids)
        partition[id] = i <= ntrain ? "train" : (i <= ntrain+nvalid ? "validation" : "test")
    end
end

d[!, :partition] = [partition[String(id)] for id in d.bridge_id]
train = d[d.partition .== "train", :]
valid = d[d.partition .== "validation", :]
test  = d[d.partition .== "test", :]
@assert isempty(intersect(Set(train.bridge_id), Set(valid.bridge_id)))
@assert isempty(intersect(Set(train.bridge_id), Set(test.bridge_id)))
@assert isempty(intersect(Set(valid.bridge_id), Set(test.bridge_id)))
println("Rows - train: $(nrow(train)), validation: $(nrow(valid)), test: $(nrow(test))")
CSV.write(joinpath(OUT_DIR, "bridge_partitions.csv"),
          DataFrame(bridge_id=collect(keys(partition)), partition=collect(values(partition))))

# -------------------- STEP 3: Fit preprocessing on training data only --------------------
# All model features are numbers after standardization and one-hot encoding.
# Original numeric columns: age, ADT, truck share, spans, dimensions, year.
const NUMERIC_FEATURES = ["age", "adt", "truck_share", "spans", "length",
                          "max_span", "deck_width", "deck_area", "year"]
const CATEGORICAL_FEATURES = ["owner", "material", "design"]
const LOG_FEATURES = Set(["adt", "length", "max_span", "deck_area"])

# Missing numerical values are represented as NaN until the training median is applied.
function numeric_value(v, name::String)
    if ismissing(v)
        return NaN
    end
    x = Float64(v)
    if !isfinite(x) || (name == "spans" && x <= 0) ||
       (name in ("length", "max_span", "deck_area") && x <= 0) ||
       (name == "deck_width" && x <= 0) ||
       (name in ("age", "adt", "truck_share") && x < 0)
        return NaN
    end
    return name in LOG_FEATURES ? log1p(x) : x
end

function categorical_value(v)
    ismissing(v) && return "Unknown"
    s = strip(String(v))
    return isempty(s) ? "Unknown" : s
end

# Sparse/missing indicators are separate to distinguish imputed values from real values.
function fit_preprocessor(df)
    stats = Dict{String,Tuple{Float64,Float64,Float64}}() # median, mean, std
    for name in NUMERIC_FEATURES
        x = [numeric_value(v, name) for v in df[!, name]]
        observed = filter(isfinite, x)
        med = isempty(observed) ? 0.0 : median(observed)
        replaced = [isfinite(v) ? v : med for v in x]
        mu = mean(replaced)
        sigma = std(replaced)
        stats[name] = (med, mu, sigma > 0 ? sigma : 1.0)
    end
    levels = Dict{String,Vector{String}}()
    for name in CATEGORICAL_FEATURES
        # Unknown is kept as an explicit category.
        levels[name] = sort!(unique(vcat([categorical_value(v) for v in df[!, name]], ["Unknown"])))
    end
    return (stats=stats, levels=levels)
end

function transform(df, prep)
    result = DataFrame()
    for name in NUMERIC_FEATURES
        vals = [numeric_value(v, name) for v in df[!, name]]
        med, mu, sigma = prep.stats[name]
        result[!, Symbol(name)] = [(isfinite(v) ? v : med) for v in vals] .- mu
        result[!, Symbol(name)] ./= sigma
        result[!, Symbol(name * "_missing")] = Float64[!isfinite(v) for v in vals]
    end
    # Explicitly mark coded width zero and ADT zero as planned in the report.
    result[!, :deck_width_zero] = Float64[!ismissing(v) && v == 0 for v in df.deck_width]
    result[!, :adt_zero] = Float64[!ismissing(v) && v == 0 for v in df.adt]
    for name in CATEGORICAL_FEATURES
        values = [categorical_value(v) for v in df[!, name]]
        known = Set(prep.levels[name])
        values = [v in known ? v : "Unknown" for v in values]
        # Drop the first category to avoid perfect collinearity with intercept.
        for (i, level) in enumerate(prep.levels[name][2:end])
            result[!, Symbol(name * "_" * string(i))] = Float64[v == level for v in values]
        end
    end
    return result
end

prep = fit_preprocessor(train)
Xtrain, Xvalid, Xtest = transform(train, prep), transform(valid, prep), transform(test, prep)
ytrain = categorical(String.(train.condition); levels=CLASSES)
yvalid = String.(valid.condition)
ytest  = String.(test.condition)
println("Number of model features: ", ncol(Xtrain))

# -------------------- STEP 4: Classifier + evaluation metrics --------------------
# MLJLinearModels MultinomialClassifier uses multinomial softmax logistic regression.
MultinomialClassifier = @load MultinomialClassifier pkg=MLJLinearModels verbosity=0

function evaluate(ytrue::Vector{String}, ypred::Vector{String})
    cm = zeros(Int, length(CLASSES), length(CLASSES))
    class_index = Dict(label => i for (i, label) in enumerate(CLASSES))
    for (t, p) in zip(ytrue, ypred)
        cm[class_index[t], class_index[p]] += 1
    end
    precision = Float64[]; recall = Float64[]; f1 = Float64[]
    for i in eachindex(CLASSES)
        tp = cm[i,i]
        prec = tp / max(sum(cm[:,i]), 1)
        rec = tp / max(sum(cm[i,:]), 1)
        push!(precision, prec)
        push!(recall, rec)
        push!(f1, prec+rec > 0 ? 2prec*rec/(prec+rec) : 0.0)
    end
    scores = (accuracy=sum(diag(cm))/sum(cm), macro_f1=mean(f1),
              balanced_accuracy=mean(recall), poor_recall=recall[3],
              poor_precision=precision[3])
    per_class = DataFrame(class=CLASSES, precision=precision, recall=recall, f1=f1,
                          support=vec(sum(cm, dims=2)))
    return scores, per_class, cm
end

# Use native Julia diagonal indexing without requiring LinearAlgebra.
# diag is defined in LinearAlgebra, so import it here.
using LinearAlgebra: diag

# Majority-class comparator based on TRAINING distribution only.
majority = first(sort(collect(CLASSES), by=c -> -count(==(c), String.(train.condition))))
base_scores, _, _ = evaluate(yvalid, fill(majority, length(yvalid)))
println("Baseline majority class: $majority; validation macro-F1: $(round(base_scores.macro_f1, digits=4))")

# Choose regularization using validation ONLY, not the test set.
results = DataFrame(lambda=Float64[], accuracy=Float64[], macro_f1=Float64[],
                    balanced_accuracy=Float64[], poor_recall=Float64[])
best_machine = nothing
best_score = -Inf
best_lambda = NaN
for lambda in [0.01, 0.1, 1.0]
    println("Training multinomial logistic regression; lambda=$lambda ...")
    model = MultinomialClassifier(lambda=lambda, penalty=:l2)
    mach = machine(model, Xtrain, ytrain)
    fit!(mach, verbosity=0)
    pred = String.(predict_mode(mach, Xvalid))
    score, _, _ = evaluate(yvalid, pred)
    push!(results, (lambda, score.accuracy, score.macro_f1,
                    score.balanced_accuracy, score.poor_recall))
    println("  validation macro-F1=$(round(score.macro_f1, digits=4)), poor recall=$(round(score.poor_recall, digits=4))")
    if score.macro_f1 > best_score
        best_score = score.macro_f1
        best_machine = mach
        best_lambda = lambda
    end
end
CSV.write(joinpath(OUT_DIR, "validation_comparison.csv"), results)
println("Selected lambda: $best_lambda (validation macro-F1=$best_score)")

# -------------------- STEP 5: One final held-out test evaluation --------------------
# Do not change hyperparameters after viewing test results.
ypred = String.(predict_mode(best_machine, Xtest))
test_scores, class_scores, cm = evaluate(ytest, ypred)
println("\nFINAL HELD-OUT TEST RESULTS")
println("Accuracy:          ", round(test_scores.accuracy, digits=4))
println("Macro-F1:          ", round(test_scores.macro_f1, digits=4))
println("Balanced accuracy: ", round(test_scores.balanced_accuracy, digits=4))
println("Poor recall:       ", round(test_scores.poor_recall, digits=4))
println("Poor precision:    ", round(test_scores.poor_precision, digits=4))
println(class_scores)
CSV.write(joinpath(OUT_DIR, "test_per_class_scores.csv"), class_scores)
CSV.write(joinpath(OUT_DIR, "test_predictions.csv"),
    DataFrame(bridge_id=test.bridge_id, year=test.year,
              actual=ytest, predicted=ypred))
cm_df = DataFrame(actual=CLASSES)
for (j, label) in enumerate(CLASSES)
    cm_df[!, Symbol("predicted_" * label)] = cm[:,j]
end
CSV.write(joinpath(OUT_DIR, "confusion_matrix.csv"), cm_df)

p = heatmap(CLASSES, CLASSES, cm, xlabel="Predicted condition", ylabel="Actual condition",
            title="Test confusion matrix", c=:blues, size=(650,520))
for i in 1:3, j in 1:3
    annotate!(p, j, i, text(string(cm[i,j]), 10, :black))
end
savefig(p, joinpath(OUT_DIR, "confusion_matrix.png"))

p2 = bar(class_scores.class, class_scores.f1, xlabel="Condition class", ylabel="F1 score",
         ylim=(0,1), title="Held-out test F1 by class", legend=false, size=(650,420))
savefig(p2, joinpath(OUT_DIR, "per_class_f1.png"))

println("\nSaved output tables and plots in: $OUT_DIR")
