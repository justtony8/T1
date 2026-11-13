#import "@preview/charged-ieee:0.1.4": ieee

#show: ieee.with(
  title: [Data-Driven Prediction of Bridge Condition Using National Bridge Inventory Data],
 
  authors: (
    (
      name: "Powei Tao",
      department: [Department of Civil and Environmental Engineering],
      organization: [University of Illinois Urbana-Champaign],
      location: [Urbana, IL, USA],
      email: "poweit2@illinois.edu",
    ),
    (
      name: "Xinyu Xu",
      department: [Department of civil engineering],
      organization: [University of Illinois Urbana-Champaign],
      location: [Urbana, IL, USA],
      email: "xinyux6@illinois.edu",
    ),
    (
      name: "Jinghao Meng",
      department: [Department of Civil and Environmental Engineering],
      organization: [University of Illinois Urbana-Champaign],
      location: [Urbana, IL, USA],
      email: "jmeng10@illinois.edu",
    ),
    (
      name: "HeeJae Jeon",
      department: [Department of Civil and Environmental Engineering],
      organization: [University of Illinois Urbana-Champaign],
      location: [Urbana, IL, USA],
      email: "heejaej2@illinois.edu",
    ),
  ),
  index-terms: ("bridge condition", "National Bridge Inventory", "classification", "K-means clustering", "machine learning"),
  bibliography: bibliography("refs.bib"),
)

= Motivation and problem


Transportation agencies manage large bridge inventories with limited budgets, time, and inspection resources. Bridge condition varies with age, structural characteristics, material type, and traffic demand, making it important to identify bridges that may require greater maintenance attention.
#v(0.5em)
We propose using historical bridge inventory data to predict bridge condition and identify characteristics associated with poor condition. The resulting models may help prioritize inspections, maintenance, and rehabilitation. We will evaluate predictive performance and determine which bridge characteristics are most strongly associated with condition differences.



= Data and Prediction Target

This project will use National Bridge Inventory (NBI) data for Illinois, obtained from the Federal Highway Administration's LTBP InfoBridge @fhwa_infobridge. The tabular dataset includes 582,165 bridge-year observations from 2002 to 2025 with 18 attributes. Each record represents one bridge in one reporting year and contains information about identification, ownership, structure, traffic, dimensions, and condition. The attributes are summarized in @nbi-attributes and @nbi-attributes-continued.



#figure(
  caption: [Description of NBI attributes used in the analysis (Part 1)],
  table(
    columns: (2.2fr, 1.0fr, 4.8fr),
    align: (left, center, left),

    table.header(
      [*Attribute Name*],
      [*Units*],
      [*Description*],
    ),

    [Year],
    [year],
    [Year corresponding to the NBI record or inspection dataset.],

    [1 - State Code],
    [code],
    [FHWA numeric code identifying the state in which the bridge is located.],

    [8 - Structure Number],
    [identifier],
    [Structure number assigned to uniquely identify a bridge within the reporting state or agency.],

    [2025 NBI Structure Number],
    [identifier],
    [Structure identifier used to associate the bridge record with the 2025 NBI dataset.],

    [22 - Owner Agency],
    [code / category],
    [Code identifying the public agency or organization responsible for ownership of the bridge.],

    [27 - Year Built],
    [year],
    [Year in which the bridge was originally constructed.],

    [29 - Average Daily Traffic],
    [vehicles/day],
    [Average number of vehicles crossing the structure per day.],

    [Bridge Age],
    [yr],
    [Age of the bridge at the time of the record, calculated from the dataset year and the year built.],

    [43A - Main Span Material],
    [category],
    [Material classification of the bridge main span, such as concrete, steel, or other structural materials.],

    [43B - Main Span Design],
    [category],
    [Structural design or construction type of the bridge main span, such as beam, girder, truss, arch, or other design types.],

  ),
) <nbi-attributes>

#figure(
  caption: [Description of NBI attributes used in the analysis (continued)],
  table(
    columns: (2.2fr, 1.0fr, 4.8fr),
    align: (left, center, left),

    table.header(
      [*Attribute Name*],
      [*Units*],
      [*Description*],
    ),

    

    [45 - Number of Spans in Main Unit],
    [count],
    [Number of individual spans contained in the main structural unit of the bridge.],

    [49 - Structure Length],
    [ft],
    [Total length of the bridge structure measured along its centerline.],

    [CAT10 - Bridge Condition],
    [category],
    [Overall bridge condition classification, expressed as Good, Fair, or Poor.],

    [CAT29 - Deck Area],
    [sq. ft.],
    [Total bridge deck area, representing the plan area of the bridge deck.],

    [48 - Length of Maximum Span],
    [ft],
    [Length of the longest individual span in the bridge structure.],

    [109 - Average Daily Truck Traffic],
    [% ADT],
    [Percentage of average daily traffic consisting of trucks.],

    [52 - Deck Width - Out to Out],
    [ft],
    [Total deck width measured from the outside edge of one side of the bridge deck to the outside edge of the other side.],
  ),
) <nbi-attributes-continued>

#v(0.5em)
The prediction target is bridge condition, categorized as Good, Fair, or Poor, making this a three-class classification task. Identification variables will be used for organization and tracking but not as predictive features. State Code and State Name are also excluded because they are constant in this Illinois-only dataset.




= Exploratory Data Analysis
== Analysis Workflow and Data Quality

The export is comma-separated with single-quoted text fields and includes some categories with commas. To ensure all columns are preserved without losing any potentially malformed lines, we read the export with a single-quote text delimiter. Identifiers are kept as strings to preserve leading zeros. We check for unexpected parsing failures when converting numeric values. We treat blank categories as missing, limit our study period to 2002–2025, and verify that the bridge-year key has no duplicate entries. Reported age agrees with reporting year minus year built for all 580,971 non-missing ages.

@missing shows the nonzero raw missing counts. The 380 records without a target are retained for the inventory audit but excluded from class comparisons and future supervised training, leaving *581,785 labeled observations*. There is no target imputation. For each EDA comparison, records missing the relevant variable are omitted only from that comparison; other available records are retained.

#figure(

  table(

    columns: (1.7fr, 1fr, .8fr), align: (left, right, right), inset: 4pt,

    table.header([*Variable*], [*Missing*], [*Percent*]),

    [Truck share of ADT], [82,581], [14.18%],

    [Main span design], [5,531], [0.95%],

    [Year built], [1,194], [0.21%],

    [Bridge age], [1,194], [0.21%],

    [Bridge condition], [380], [0.07%],

    [Main span material], [222], [0.04%],

    [Number of spans], [1], [\<0.01%],

  ),

  caption: [Raw missingness in the 582,165 retained observations. All remaining exported fields have zero blank entries; coded zeros and invalid counts are audited separately.],

) <missing>

Span counts contain 18 negative and 1,035 zero values, in addition to one blank. Non-positive span counts are identified and set to missing for valid-count summaries and planned model inputs. However, their original values are still available in the source data. Traffic has 755 zeros; these are retained and flagged since the export alone cannot determine whether they represent no traffic or a reporting error. Maximum span and deck area have 1,866 and 38 zeros, respectively; these require interpretation prior to being used as physical measurements.
Deck width requires special handling: 72,503 records have width zero, and 71,995 of these (99.30%) are coded as culverts. FHWA documents zero deck-width coding for culverts, structures under fill, and structures without structural decks @fhwa_condition. Therefore, width zeros are not automatically treated as erroneous or used to exclude culverts. Planned preprocessing will retain a zero-width indicator, preserve design type, and distinguish positive measured width from this coding pattern. Extreme positive dimensions are retained for EDA and flagged for review rather than removed using an arbitrary cutoff.

== Numeric Distributions
@summary reports numerical characteristics using available observations. Right-skewness is observed in both traffic and bridge dimensions.
The median ADT is 309 vehicles/day, the mean is 5,257 vehicles/day, and the maximum is 590,800 vehicles/day. Deck area has a median of 1,946 sq. ft. and a mean of 5,425 sq. ft. These differences support reporting medians and interquartile ranges alongside means and considering logarithmic transformations for traffic and positive geometric variables.

#figure(

  table(

    columns: (1.25fr, .8fr, .8fr, 1.15fr), align: (left, right, right, right), inset: 3.4pt,

    table.header([*Variable*], [*Mean*], [*Median*], [*Q1--Q3*]),

    [Age (yr)], [37.82], [33], [20--50],

    [ADT (veh/day)], [5,257], [309], [75--3,050],

    [Truck share (%)], [9.58], [7], [2--13],

    [Valid span count], [2.31], [2], [1--3],

    [Length (ft)], [125.25], [65.9], [38.7--132.9],

    [Maximum span (ft)], [50.99], [44.9], [26.9--64.0],

    [Deck width (ft)], [30.86], [27.6], [24.0--36.1],

    [Deck area (sq. ft.)], [5,425], [1,946], [1,147--4,668],

  ),

  caption: [Available-case numerical summaries for 2002--2025. Age n = 580,971; truck share n = 499,584; valid span count n = 581,111; all other rows n = 582,165. Coded zeros are retained except for nonpositive span counts. Q1 and Q3 are the 25th and 75th percentiles.],

) <summary>

== Condition Distribution and Class Imbalance
Among labeled observations, 338,609 are Good (58.20%), 211,477 Fair (36.35%), and 31,699 Poor (5.45%), as shown in @condition-fig. A classifier that always predicts Good would achieve 58.20% accuracy on this pooled sample while identifying no Poor observations. This descriptive baseline is not a held-out performance result, but it demonstrates why accuracy alone will be insufficient. Poor-class recall and macro-averaged F1 will receive particular attention.

#figure(image("figures/01_condition.svg", width: 100%), caption: [Condition distribution among 581,785 labeled bridge-year observations. Poor is the smallest class, motivating class-specific evaluation.]) <condition-fig>

== Bridge Age and Condition
The age distributions differ substantially across classes (@age-fig). Median ages are 24, 47, and 57 years for Good, Fair, and Poor observations, respectively; their means are 27.33, 50.63, and 64.54 years.

Among labeled records with known age, the proportion classified Poor increases from 0.21% for ages 0–19 to 2.21% for ages 20–39, 8.77% for ages 40–59, 11.31% for ages 60–79, and 20.17% for ages 80 or older. These are within-band percentages, not shares of all Poor bridges.

#figure(image("figures/02_age.svg", width: 100%), caption: [(a) Age by condition; boxes show quartiles, center lines show medians, and whiskers extend to the last observation within 1.5 interquartile ranges. Outlier points are hidden for readability, but retained in the statistics. (b) Poor-condition percentage within each age band. Both panels use 580,652 records with known condition and age. Older observations have higher Poor prevalence in this sample.]) <age-fig>

These results support age as a candidate predictor, but they do not isolate a causal age effect. A bridge can appear repeatedly, and age can be associated with material, design, rehabilitation, and reporting period. The distributions also overlap. Consequently, age alone will not be assumed to determine condition, and no significance tests treating all bridge-year rows as independent are reported.

== Material and Structural Characteristics
@material-fig compares class composition within the six most common material categories and a pooled smaller-material category. The Poor percentage is 13.93% for Steel, 6.77% for Steel Continuous, 5.89% for Concrete, and 3.32% for Prestressed Concrete. Continuous Concrete and Continuous Prestressed Concrete have Poor shares of 2.82% and 2.01%, respectively.

Material categories use the export's labels; continuous and noncontinuous types are kept separate.

The largest design categories are Box Beam or Girders – Multiple (202,962 observations), Stringer/Multi-beam or Girder (167,672), and Culvert (104,985). These design counts include records without a condition label.

Together with the width audit, this mix shows that the dataset includes substantially different structural configurations. Material and design should therefore enter the model as categorical predictors.

Unadjusted material differences may reflect age, design, ownership, and exposure differences, so they do not establish that any material intrinsically deteriorates faster.



#figure(image("figures/03_material.svg", width: 100%), caption: [Condition percentages within material groups. Labels give labeled bridge-year counts. The six largest raw material groups are shown separately; smaller groups are pooled. The 193 labeled records with missing material are omitted from this figure. Unadjusted material differences motivate multivariable analysis rather than a causal ranking of materials.]) <material-fig>

== Traffic and Geometric Characteristics
Traffic distributions overlap across classes (@traffic-fig). Median ADT is 225 vehicles/day for Good, 650 for Fair, and 350 for Poor observations. Thus, the median does not increase monotonically from Good to Poor.

Traffic remains a plausible complementary predictor, but this EDA does not support the simple claim that higher traffic alone implies poorer condition. The figure uses a log10(1 + ADT) scale and retains traffic zeros.


#figure(image("figures/04_traffic.svg", width: 80%), caption: [ADT by condition on a log10(1 + ADT) scale, with tick labels expressed in vehicles/day. Box and whisker conventions match @age-fig; outlier points are hidden. The 581,785 labeled observations show substantial overlap and a nonmonotonic ordering of class medians.]) <traffic-fig>

Median structure lengths are 62.0, 76.1, and 72.2 ft for Good, Fair, and Poor, respectively. Median deck areas are 1,811, 2,334, and 2,057 sq. ft.

These contrasts likewise do not follow a monotonic class ordering. Geometry may add information in combination with age and design, but redundant geometric predictors and the coding of culverts will need attention when interpreting model importance.

== Reporting-Year Patterns and Data Limitations
The share of labeled records classified Good decreases from 70.91% in 2002 to 44.61% in 2025, while the Poor share increases from 3.58% to 9.52% (@time-fig(a)). The annual labeled sample grows from 20,724 to 26,927. These curves describe the supplied cohort and its changing observed composition; they do not establish statewide causal deterioration rates. All 26,927 grouping identifiers occur in 2025. Combined with InfoBridge's current-submittal selection behavior @fhwa_infobridge, this is consistent with historical records linked to the selected 2025 inventory. It should not be assumed to include bridges retired before 2025 or the complete historical Illinois inventory.

#figure(image("figures/05_time.svg", width: 100%), caption: [(a) Annual condition shares, with each year's labeled bridge-year count as denominator. (b) Truck-share missingness among all retained records in each year. Annual class composition changes while missingness drops sharply in 2013, motivating reporting-year sensitivity analysis and careful missing-value treatment.]) <time-fig>

Truck-share missingness averages 33.41% during 2002--2012 but only 0.05% during 2013--2025 (@time-fig(b)). The reason for this discontinuity is not established by the supplied file. Deleting every incomplete row would leave 494,364 observations and disproportionately remove early-period data. For modeling, predictor missingness will instead be handled within the training pipeline, with a sensitivity analysis excluding truck share. Missingness indicators will be interpreted cautiously because they may encode reporting practices rather than structural condition.

The analysis is descriptive and observation-weighted: bridges recorded for more years contribute more rows. It is neither bridge-equal-weighted nor deck-area-weighted, and these percentages should not be presented as official statewide performance measures. Maintenance histories, environmental exposure, and component ratings are unavailable in this export. These limitations constrain causal interpretation, prediction of individual deterioration trajectories, and generalization beyond the selected Illinois cohort.


= Predictive Modeling

== Research Objective and Modeling Approaches

This study examined whether bridge inventory characteristics could support the classification and characterization of bridge condition using Illinois National Bridge Inventory (NBI) records from 2002 to 2025. The supervised classification task was to distinguish Good, Fair, and Poor conditions using bridge characteristics such as age, traffic, structural type, and dimensions. Three complementary analytical approaches were considered: multinomial logistic regression as an interpretable linear baseline, random forest as a nonlinear classifier, and K-means as an unsupervised method for identifying groups of similar bridge observations.

#v(0.5em)

The supervised models were evaluated on their ability to identify condition categories for held-out bridge records, with particular attention to the minority Poor class. K-means addressed a different question: whether bridge observations form groups with distinct condition compositions, without using condition labels to define the groups. Because clustering and classification have different objectives, their scores are not directly comparable. The analysis concerns classification of recorded condition in the same reporting year, not forecasting future deterioration or replacing formal bridge inspections.

== Data Preprocessing and Validation Strategy

The initial dataset contained 582,165 bridge-year observations. After excluding 380 records without condition labels, 581,785 observations from 26,927 unique bridges remained. Predictors considered for supervised classification included bridge age, average daily traffic, truck traffic percentage, owner agency, main span material and design, number of spans, structure length, maximum span length, deck width, deck area, and reporting year. Bridge identifiers were not predictive inputs. For logistic regression, missing numerical values were filled using training-set medians, missing categorical entries were coded as Unknown, and categorical predictors were one-hot encoded. Selected nonnegative variables were transformed using log(1+x), with continuous predictors standardized using training-set statistics. Indicators were used for selected missing and zero-valued measurements.

#v(0.5em)

To reduce leakage from repeated annual observations, the supervised analyses used bridge-level partitions: all records belonging to the same bridge were assigned to a single partition. Approximately 60% of bridges were used for training, 20% for validation, and 20% for testing, with a fixed random seed of 492. The resulting allocation is shown in @ch4-data-table. Random forest used the same bridge partitions and condition labels as logistic regression, allowing a direct comparison on the same 116,845 test observations. Model selection was based on validation performance; the held-out test set was used for final evaluation. K-means cluster summaries were also reported by partition, but its clusters were evaluated descriptively rather than as supervised predictions.

#figure(
  table(
    columns: (1.1fr, 0.8fr, 1.1fr, 0.8fr),
    align: (left, right, right, right),
    table.header(
      [*Partition*],
      [*Bridges*],
      [*Observations*],
      [*Share*],
    ),
    [Training], [16,156], [348,406], [59.89%],
    [Validation], [5,385], [116,534], [20.03%],
    [Test], [5,386], [116,845], [20.08%],
    [*Total*], [*26,927*], [*581,785*], [*100%*],
  ),
  caption: [Bridge-level dataset partitions and bridge-year observations.]
) <ch4-data-table>

== Multinomial Logistic Regression

A multinomial logistic regression model with L2 regularization was implemented in Julia using MLJ and MLJLinearModels. It was selected as a baseline because it provides a relatively simple approach to three-class classification. The regularization parameter lambda was varied across 0.01, 0.1, and 1.0, and validation macro-F1 was used to select the final setting. Macro-F1 assigns equal importance to Good, Fair, and Poor, which is important because Poor observations account for only about 5.45% of the labeled data. As shown in @ch4-lr-val-table, lambda = 0.01 gave the highest validation macro-F1 (0.4599); all three tested settings had zero Poor recall.

#figure(
  table(
    columns: (0.75fr, 0.95fr, 0.95fr, 1.2fr, 0.95fr),
    align: center,
    table.header(
      [*Lambda*],
      [*Accuracy*],
      [*Macro-F1*],
      [*Balanced accuracy*],
      [*Poor recall*],
    ),
    [0.01], [0.7062], [0.4599], [0.4699], [0.0000],
    [0.1], [0.7036], [0.4576], [0.4674], [0.0000],
    [1.0], [0.6713], [0.4316], [0.4414], [0.0000],
  ),
  caption: [Logistic regression validation scores across L2 regularization settings.]
) <ch4-lr-val-table>

#v(0.5em)

On the held-out test set, the selected logistic regression model achieved 70.53% accuracy, a macro-F1 of 0.4604, and 47.12% balanced accuracy. Good and Fair achieved F1 scores of 0.8029 and 0.5783, respectively, but Poor achieved an F1 score and recall of zero. None of the 6,492 actual Poor observations was correctly predicted: 1,388 were classified as Good and 5,104 as Fair. These findings indicate that acceptable overall accuracy can conceal a complete failure to identify a relatively rare but practically important condition category.

== Random Forest Classification

A random forest classifier was evaluated to test whether a tree-based model could better represent nonlinear patterns and interactions in the bridge characteristics. Three model configurations were compared by changing the number of trees, maximum depth, and minimum leaf size together. As shown in @ch4-rf-val-table, validation macro-F1 improved from 0.4951 to 0.5234 across the tested configurations. The configuration with 100 trees, maximum depth 20, and minimum leaf size 5 achieved the highest validation macro-F1 (0.5234) and was selected for final testing. Because all three parameters changed together, the improvement cannot be attributed to any single parameter. The validation results are further illustrated in @ch4-rf-val-fig.

#figure(
  table(
    columns: (0.8fr, 0.9fr, 0.8fr, 0.9fr, 0.9fr),
    align: center,
    table.header(
      [*Trees*],
      [*Max depth*],
      [*Min leaf*],
      [*Macro-F1*],
      [*Poor recall*],
    ),
    [30], [12], [20], [0.4951], [0.0205],
    [60], [16], [10], [0.5111], [0.0390],
    [100], [20], [5], [0.5234], [0.0590],
  ),
  caption: [Random forest configurations and their validation performance.]
) <ch4-rf-val-table>

#figure(
  image("ch4_figures/rf_validation_comparison.png", width: 100%),
  caption: [Validation macro-F1 for the three random forest configurations. Tree count, depth, and leaf size were varied together.]
) <ch4-rf-val-fig>

#v(0.5em)

The selected random forest achieved 73.29% test accuracy, a macro-F1 of 0.5317, and 52.54% balanced accuracy. Good, Fair, and Poor F1 scores were 0.8173, 0.6489, and 0.1288, respectively. Unlike logistic regression, random forest correctly identified 475 of the 6,492 Poor observations, resulting in 7.32% Poor recall and 53.85% Poor precision. Nevertheless, it still missed 6,017 Poor observations: 655 were classified as Good and 5,362 as Fair. The confusion matrix in @ch4-rf-cm-fig illustrates this imbalance. Therefore, the model improved minority-class detection but remained inadequate as a stand-alone screening tool for identifying Poor bridges.

#figure(
  image("ch4_figures/rf_confusion_matrix.png", width: 92%),
  caption: [Random forest confusion matrix for the held-out test dataset. Rows are actual classes and columns are predicted classes.]
) <ch4-rf-cm-fig>

== K-means Clustering Analysis

K-means clustering was used as a complementary unsupervised analysis of the bridge records. Unlike the supervised classifiers, K-means creates clusters based on similarity in the input feature space, rather than directly predicting Good, Fair, or Poor. Candidate cluster counts from K = 2 through K = 8 were compared using average silhouette score and within-cluster sum of squares (WCSS). As shown in @ch4-k-sil-fig, K = 2 had the highest silhouette score (0.3103), compared with approximately 0.18 to 0.21 for the larger candidate values. WCSS decreased steadily as K increased, but @ch4-k-elbow-fig did not show a clear elbow. Accordingly, K = 2 was selected primarily on the silhouette criterion. Its score indicates some cluster structure, but not a strong separation.

#figure(
  image("ch4_figures/kmeans_silhouette.png", width: 100%),
  caption: [Average silhouette score for K-means models with two to eight clusters.]
) <ch4-k-sil-fig>

#figure(
  image("ch4_figures/kmeans_elbow.png", width: 100%),
  caption: [K-means within-cluster sum of squares for two to eight clusters.]
) <ch4-k-elbow-fig>

#v(0.5em)

The condition distributions differed between the two clusters, as summarized for the held-out test partition in @ch4-cluster-fig. Cluster 1 contained 83,530 observations and had 63.01% Good, 31.92% Fair, and 5.07% Poor. Cluster 2 contained 33,315 observations and had 45.65% Good, 47.59% Fair, and 6.77% Poor. Cluster 2 therefore contained a larger share of Fair and Poor observations, although it still included many Good observations. Similar broad differences were present in the reported training and validation cluster summaries. These findings suggest an association between the clustering features and condition composition, but the clusters do not constitute reliable Good/Fair/Poor predictions. The feature-specific interpretation of each cluster requires inspection of the original-scale centroids and the exact clustering input variables.

#figure(
  image("ch4_figures/kmeans_test_condition_composition.png", width: 100%),
  caption: [Condition composition of the two K-means clusters in the held-out test partition.]
) <ch4-cluster-fig>

== Comparison of Modeling Results

Since logistic regression and random forest were evaluated on the same bridge-level test partition, their classification metrics can be compared directly. @ch4-model-compare-table and @ch4-model-compare-fig show that random forest outperformed logistic regression on accuracy (73.29% versus 70.53%), macro-F1 (0.5317 versus 0.4604), and balanced accuracy (52.54% versus 47.12%). Class-specific F1 also increased for Good and Fair, and Poor F1 improved from zero to 0.1288, as shown in @ch4-f1-fig. The findings are consistent with a benefit from using a more flexible model, although other differences in model specification could also contribute to the improvement.

#figure(
  table(
    columns: (1.45fr, 1fr, 1fr),
    align: (left, center, center),
    table.header(
      [*Test metric*],
      [*Logistic regression*],
      [*Random forest*],
    ),
    [Accuracy], [0.7053], [0.7329],
    [Macro-F1], [0.4604], [0.5317],
    [Balanced accuracy], [0.4712], [0.5254],
    [Good F1], [0.8029], [0.8173],
    [Fair F1], [0.5783], [0.6489],
    [Poor F1], [0.0000], [0.1288],
    [Poor recall], [0.0000], [0.0732],
  ),
  caption: [Held-out test performance of the supervised classification models.]
) <ch4-model-compare-table>

#figure(
  image("ch4_figures/model_performance_comparison.png", width: 100%),
  caption: [Comparison of overall test metrics and Poor recall for logistic regression and random forest.]
) <ch4-model-compare-fig>

#figure(
  image("ch4_figures/class_f1_comparison.png", width: 100%),
  caption: [Class-specific test F1 scores of logistic regression and random forest.]
) <ch4-f1-fig>

#v(0.5em)

The K-means results add a different perspective by showing that groups formed without condition labels have different proportions of Good, Fair, and Poor observations. However, a silhouette score measures cluster cohesion and separation, not predictive classification accuracy. It would therefore be inappropriate to rank K-means alongside logistic regression and random forest using the same performance metrics. Taken together, the analyses suggest that nonlinear supervised classification improves test performance and that unsupervised group structure is associated with, but does not uniquely determine, observed bridge condition.
#v(0.5em)

The three modeling approaches are summarized in @ch4-three-model-table. Logistic regression and random forest were evaluated as supervised classification models, whereas K-means was used to identify groups of bridges with similar characteristics. Random forest achieved the highest classification performance, while K-means identified two clusters with different bridge condition distributions. These results provide complementary insights into bridge condition classification and the underlying structure of the NBI dataset.

#figure(
  table(
    columns: (1.15fr, 1.25fr, 1.65fr),
    align: (left, left, left),
    table.header(
      [*Model*],
      [*Objective*],
      [*Main Result*],
    ),
    [Logistic Regression],
    [Condition Classification],
    [Macro-F1: 0.4604],

    [Random Forest],
    [Condition Classification],
    [Macro-F1: 0.5317],

    [K-means],
    [Bridge Clustering],
    [K = 2; Silhouette: 0.3103],
  ),
  caption: [Summary of the three modeling approaches and their main results.]
) <ch4-three-model-table>


== Discussion, Limitations, and Future Work

The primary limitation of both supervised models was weak identification of the Poor category. Poor accounted for only about 5.45% of the labeled records. Logistic regression detected none of the Poor observations, while random forest detected only 7.32%. This class imbalance may contribute to the tendency to predict the more common Good and Fair conditions. Furthermore, bridge age, traffic, material, design, and dimensions may interact in nonlinear ways that are not fully captured by a simple linear specification. The improvements with random forest are consistent with this possibility but do not establish it as a causal explanation. The clustering results likewise show differences in condition composition, but the relatively modest silhouette score and overlap across clusters limit their interpretation.

#v(0.5em)

A further limitation is that this analysis classifies recorded condition in the same year rather than predicting future structural deterioration. Detailed maintenance history, local environmental exposure, and component-level information were not included in the reported predictor set. Future work should evaluate class-weighted classifiers, alternative probability thresholds, targeted feature interactions, and additional nonlinear models to improve Poor recall while monitoring false alarms. Sensitivity analyses and inspection of K-means centroids in original measurement units would help explain which variables drive the reported results. These improvements have not yet been tested in the present results and should not be presented as demonstrated gains. Overall, random forest provided the strongest supervised performance of the models evaluated, but neither supervised model is currently sufficiently reliable for independent bridge maintenance prioritization.



= Team Plan

Project work will be divided among data preparation and validity checks, exploratory analysis and visualization, predictive modeling and evaluation, and report integration. Team members will organize repeated bridge records, define preprocessing and predictor rules, examine condition patterns, train and evaluate classification models, and integrate the results into the report.

#v(0.5em)

All team members will interpret results, review analyses and code, prepare figures and tables, and edit the final report. The team will jointly review the cross-year identifier mapping, preprocessing rules, split assignments, model results, and final interpretation. Contributions will be managed through the shared GitHub repository, with code, figures, and text reviewed before submission.
