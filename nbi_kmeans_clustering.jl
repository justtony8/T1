# CEE 492 - Complementary K-means clustering of NBI bridge records
# Run in VS Code's Julia terminal: include("nbi_kmeans_clustering.jl")
# Install once:
#   import Pkg
#   Pkg.add(["CSV", "DataFrames", "Clustering", "Plots"])
#
# This is an unsupervised analysis. Bridge-condition labels are excluded from
# model fitting and are used only after clustering to describe each cluster.

using CSV
using DataFrames
using Statistics
using Random
using LinearAlgebra
using Clustering

# Render plots without opening a GUI window, including in terminals and CI.
ENV["GKSwstype"] = "100"
using Plots

const DATA_FILE = joinpath(@__DIR__, "Selected_Bridges_September_24_2026_03_51_03.txt")
const PARTITION_FILE = joinpath(@__DIR__, "model_results", "bridge_partitions.csv")
const OUT_DIR = joinpath(@__DIR__, "kmeans_results")
const CLASSES = ["Good", "Fair", "Poor"]
const FEATURES = ["age", "adt", "truck_share", "spans", "length",
                  "max_span", "deck_width", "deck_area", "year"]
const LOG_FEATURES = Set(["adt", "length", "max_span", "deck_area"])
const K_VALUES = 2:8
const N_STARTS = 20
const SILHOUETTE_SAMPLE_SIZE = 2_000
const RANDOM_SEED = 492

mkpath(OUT_DIR)

# -------------------- STEP 1: Read data and reuse the supervised split --------------------
@assert isfile(DATA_FILE) "Data file not found: $DATA_FILE"
@assert isfile(PARTITION_FILE) "Partition file not found: $PARTITION_FILE. Run nbi_logistic_regression.jl first."

raw = CSV.read(DATA_FILE, DataFrame;
    quotechar='\'',
    types=Dict("8 - Structure Number" => String,
               "2025 NBI Structure Number" => String),
    missingstring=["", "NA", "N/A"])

d = raw[(raw[!, "Year"] .>= 2002) .& (raw[!, "Year"] .<= 2025), :]
rename!(d, Dict(
    "Year" => "year",
    "2025 NBI Structure Number" => "bridge_id",
    "29 - Average Daily Traffic" => "adt",
    "45 - Number of Spans in Main Unit" => "spans",
    "49 - Structure Length (ft.)" => "length",
    "CAT10 - Bridge Condition" => "condition",
    "Bridge Age (yr)" => "age",
    "CAT29 - Deck Area (sq. ft.)" => "deck_area",
    "48 - Length of Maximum Span (ft.)" => "max_span",
    "109 - Average Daily Truck Traffic (Percent ADT)" => "truck_share",
    "52 - Deck Width - Out to Out (ft.)" => "deck_width",
))

# Match the labeled population used by the supervised analysis.
filter!(row -> !ismissing(row.condition) && String(row.condition) in CLASSES, d)
@assert all(.!ismissing.(d.bridge_id)) "Missing bridge ID: cannot reuse the grouped partition."

partition_df = CSV.read(PARTITION_FILE, DataFrame;
    types=Dict("bridge_id" => String, "partition" => String))
partition = Dict(String(row.bridge_id) => String(row.partition) for row in eachrow(partition_df))
@assert all(id -> haskey(partition, String(id)), d.bridge_id) "Some bridge IDs are absent from bridge_partitions.csv."
d[!, :partition] = [partition[String(id)] for id in d.bridge_id]

train = d[d.partition .== "train", :]
valid = d[d.partition .== "validation", :]
test = d[d.partition .== "test", :]
println("Rows - train: $(nrow(train)), validation: $(nrow(valid)), test: $(nrow(test))")

# -------------------- STEP 2: Fit numeric preprocessing on training data only --------------------
function numeric_value(v, name::String)
    ismissing(v) && return NaN
    x = Float64(v)
    if !isfinite(x) ||
       (name == "spans" && x <= 0) ||
       (name in ("length", "max_span", "deck_area", "deck_width") && x <= 0) ||
       (name in ("age", "adt", "truck_share") && x < 0)
        return NaN
    end
    return name in LOG_FEATURES ? log1p(x) : x
end

function fit_numeric_preprocessor(df)
    medians = Float64[]
    means = Float64[]
    scales = Float64[]
    missing_counts = Int[]

    for name in FEATURES
        values = [numeric_value(v, name) for v in df[!, name]]
        observed = filter(isfinite, values)
        @assert !isempty(observed) "No valid training values for $name."
        med = median(observed)
        completed = [isfinite(v) ? v : med for v in values]
        mu = mean(completed)
        sigma = std(completed)
        push!(medians, med)
        push!(means, mu)
        push!(scales, sigma > 0 ? sigma : 1.0)
        push!(missing_counts, count(!isfinite, values))
    end

    return (medians=medians, means=means, scales=scales,
            missing_counts=missing_counts)
end

function transform_numeric(df, prep)
    X = Matrix{Float64}(undef, nrow(df), length(FEATURES))
    for (j, name) in enumerate(FEATURES)
        for (i, value) in enumerate(df[!, name])
            x = numeric_value(value, name)
            completed = isfinite(x) ? x : prep.medians[j]
            X[i, j] = (completed - prep.means[j]) / prep.scales[j]
        end
    end
    @assert all(isfinite, X) "Preprocessed matrix contains a nonfinite value."
    return X
end

prep = fit_numeric_preprocessor(train)
Xtrain = transform_numeric(train, prep)
Xvalid = transform_numeric(valid, prep)
Xtest = transform_numeric(test, prep)

CSV.write(joinpath(OUT_DIR, "preprocessing_statistics.csv"), DataFrame(
    feature=FEATURES,
    training_median=prep.medians,
    training_mean=prep.means,
    training_std=prep.scales,
    training_missing=prep.missing_counts,
    log1p_transformed=[name in LOG_FEATURES for name in FEATURES],
))

# -------------------- STEP 3: Repeated-start K-means --------------------
# Clustering.jl expects features by observations, so the matrix is transposed.
function fit_best_kmeans(X::Matrix{Float64}, k::Int; nstarts::Int=N_STARTS)
    data = permutedims(X)
    best_result = nothing
    best_cost = Inf
    for start in 1:nstarts
        Random.seed!(RANDOM_SEED + 10_000k + start)
        result = kmeans(data, k; init=:kmpp, maxiter=300, tol=1e-6, display=:none)
        cost = sum(result.costs)
        if cost < best_cost
            best_result = result
            best_cost = cost
        end
    end
    return best_result, best_cost
end

function assign_nearest(X::Matrix{Float64}, centers::Matrix{Float64})
    labels = Vector{Int}(undef, size(X, 1))
    for i in axes(X, 1)
        best_cluster = 1
        best_distance = Inf
        for cluster in axes(centers, 2)
            distance = 0.0
            @inbounds for j in axes(X, 2)
                delta = X[i, j] - centers[j, cluster]
                distance += delta * delta
            end
            if distance < best_distance
                best_distance = distance
                best_cluster = cluster
            end
        end
        labels[i] = best_cluster
    end
    return labels
end

# Exact silhouette calculation within a reproducible training subsample.
# Distances are accumulated by cluster without storing an m-by-m matrix.
function sampled_silhouette(X::Matrix{Float64}, labels::Vector{Int}, k::Int;
                            sample_size::Int=SILHOUETTE_SAMPLE_SIZE)
    rng = MersenneTwister(RANDOM_SEED + k)
    m = min(sample_size, size(X, 1))
    sample_idx = randperm(rng, size(X, 1))[1:m]
    sample_labels = labels[sample_idx]
    cluster_counts = [count(==(cluster), sample_labels) for cluster in 1:k]
    distance_sums = zeros(Float64, m, k)

    for a in 1:(m - 1)
        ia = sample_idx[a]
        for b in (a + 1):m
            ib = sample_idx[b]
            squared_distance = 0.0
            @inbounds for j in axes(X, 2)
                delta = X[ia, j] - X[ib, j]
                squared_distance += delta * delta
            end
            distance = sqrt(squared_distance)
            distance_sums[a, sample_labels[b]] += distance
            distance_sums[b, sample_labels[a]] += distance
        end
    end

    values = zeros(Float64, m)
    for i in 1:m
        own = sample_labels[i]
        if cluster_counts[own] <= 1
            values[i] = 0.0
            continue
        end
        within = distance_sums[i, own] / (cluster_counts[own] - 1)
        between = minimum(distance_sums[i, c] / cluster_counts[c]
                          for c in 1:k if c != own && cluster_counts[c] > 0)
        values[i] = (between - within) / max(within, between)
    end
    return mean(values)
end

selection = DataFrame(k=Int[], within_cluster_ss=Float64[],
                      average_silhouette=Float64[], converged=Bool[],
                      iterations=Int[])
models = Dict{Int,Any}()

for k in K_VALUES
    println("Fitting K-means with k=$k and $N_STARTS starts ...")
    result, cost = fit_best_kmeans(Xtrain, k)
    score = sampled_silhouette(Xtrain, result.assignments, k)
    models[k] = result
    push!(selection, (k, cost, score, result.converged, result.iterations))
    println("  WCSS=$(round(cost, digits=1)); silhouette=$(round(score, digits=4))")
end

# Select the largest silhouette score; WCSS is retained as a secondary diagnostic.
best_row = selection[argmax(selection.average_silhouette), :]
best_k = best_row.k
best_model = models[best_k]
CSV.write(joinpath(OUT_DIR, "k_selection.csv"), selection)
println("Selected k=$best_k with sampled silhouette=$(round(best_row.average_silhouette, digits=4))")

# -------------------- STEP 4: Held-out assignment and post hoc description --------------------
train_cluster = best_model.assignments
valid_cluster = assign_nearest(Xvalid, best_model.centers)
test_cluster = assign_nearest(Xtest, best_model.centers)

assignments_df = vcat(
    DataFrame(bridge_id=String.(train.bridge_id), year=train.year,
              partition="train", condition=String.(train.condition), cluster=train_cluster),
    DataFrame(bridge_id=String.(valid.bridge_id), year=valid.year,
              partition="validation", condition=String.(valid.condition), cluster=valid_cluster),
    DataFrame(bridge_id=String.(test.bridge_id), year=test.year,
              partition="test", condition=String.(test.condition), cluster=test_cluster),
)
CSV.write(joinpath(OUT_DIR, "cluster_assignments.csv"), assignments_df)

summary = DataFrame(partition=String[], cluster=Int[], observations=Int[],
                    good_count=Int[], fair_count=Int[], poor_count=Int[],
                    good_share=Float64[], fair_share=Float64[], poor_share=Float64[])
for part in ("train", "validation", "test")
    subset = assignments_df[assignments_df.partition .== part, :]
    for cluster in 1:best_k
        conditions = subset.condition[subset.cluster .== cluster]
        counts = [count(==(label), conditions) for label in CLASSES]
        total = length(conditions)
        shares = total > 0 ? counts ./ total : zeros(3)
        push!(summary, (part, cluster, total, counts[1], counts[2], counts[3],
                        shares[1], shares[2], shares[3]))
    end
end
CSV.write(joinpath(OUT_DIR, "cluster_condition_summary.csv"), summary)

centroids = DataFrame(feature=FEATURES)
for cluster in 1:best_k
    centroids[!, Symbol("cluster_" * string(cluster))] = best_model.centers[:, cluster]
end
CSV.write(joinpath(OUT_DIR, "standardized_cluster_centroids.csv"), centroids)

# -------------------- STEP 5: Diagnostic figures --------------------
p1 = plot(selection.k, selection.average_silhouette;
          marker=:circle, xlabel="Number of clusters (k)",
          ylabel="Average silhouette", legend=false,
          title="K-means silhouette selection")
p2 = plot(selection.k, selection.within_cluster_ss;
          marker=:circle, xlabel="Number of clusters (k)",
          ylabel="Within-cluster sum of squares", legend=false,
          title="K-means elbow diagnostic")
savefig(plot(p1, p2; layout=(1, 2), size=(1000, 420)),
        joinpath(OUT_DIR, "k_selection.png"))

test_summary = summary[summary.partition .== "test", :]
condition_matrix = Matrix(test_summary[:, [:good_share, :fair_share, :poor_share]])
p3 = bar(string.(test_summary.cluster), condition_matrix;
         label=permutedims(CLASSES),
         xlabel="Cluster", ylabel="Share of test observations",
         ylim=(0, 1), title="Held-out condition composition by cluster",
         size=(700, 450))
savefig(p3, joinpath(OUT_DIR, "test_cluster_condition_composition.png"))

println("Saved K-means tables and figures in: $OUT_DIR")
println("Condition labels were used only for post hoc cluster description.")
