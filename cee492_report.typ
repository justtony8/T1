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
  index-terms: ("Optional", "Keywords", "Here"),
  bibliography: bibliography("refs.bib"),
)

= Motivation and problem


Transportation agencies are responsible for maintaining a large number of bridges while working with limited budgets, time, and inspection resources. Bridge condition can vary depending on factors such as age, structural characteristics, material type, and traffic demand. Therefore, identifying bridges that may require greater maintenance attention is an important part of infrastructure management.
#v(0.5em)
The goal of this project is to investigate whether historical bridge inventory data can be used to predict bridge condition. By identifying characteristics associated with bridges in poorer condition, the analysis may provide useful information for prioritizing inspection, maintenance, and rehabilitation activities. The project will focus not only on prediction performance but also on identifying which bridge characteristics are most strongly associated with differences in bridge condition.


= Data and Prediction Target

This project will use National Bridge Inventory (NBI) data for Illinois, obtained from the Federal Highway Administration's LTBP InfoBridge @fhwa_infobridge. The data were downloaded in tabular format and include 582,165 bridge-year observations from 2002 through 2025 with 18 attributes. Each row represents a bridge record for a specific year and includes identification, ownership, structural, traffic, dimensional, and condition information. The data are stored in a tabular format suitable for statistical analysis and predictive modeling. The 18 attributes included in the dataset are summarized in @nbi-attributes and @nbi-attributes-continued.

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

    [43A - Main Span Material],
    [category],
    [Material classification of the bridge main span, such as concrete, steel, or other structural materials.],

    [43B - Main Span Design],
    [category],
    [Structural design or construction type of the bridge main span, such as beam, girder, truss, arch, or other design types.],

    [45 - Number of Spans in Main Unit],
    [count],
    [Number of individual spans contained in the main structural unit of the bridge.],

    [49 - Structure Length],
    [ft],
    [Total length of the bridge structure measured along its centerline.],

    [CAT10 - Bridge Condition],
    [category],
    [Overall bridge condition classification, expressed as Good, Fair, or Poor.],

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

    [Bridge Age],
    [yr],
    [Age of the bridge at the time of the record, calculated from the dataset year and the year built.],

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
The primary prediction target will be Bridge Condition, which classifies bridges as Good, Fair, or Poor. Therefore, the predictive task will be treated as a classification problem. Identification variables such as Structure Number will be retained for organizing and tracking observations but will not be used directly as predictive features. Because State Code and State Name are constant for the Illinois-only dataset, they will also not provide useful information for predicting condition.


= Proposed Study
The study will begin with data cleaning and exploratory data analysis. Missing or inconsistent values will be identified and handled before model development. Summary statistics and visualizations will then be used to examine the distribution of Good, Fair, and Poor bridge conditions and to investigate relationships between bridge condition and characteristics such as bridge age, traffic volume, structural material, structural design, bridge length, deck area, and number of spans.
#v(0.5em)
Next, classification models will be developed to predict bridge condition using selected bridge characteristics. The data will be separated into training and testing sets so that predictive performance can be evaluated using observations that are not used for model training. Because the dataset contains repeated observations of bridges across multiple years, the data splitting strategy will also consider bridge identifiers to reduce the possibility that records from the same bridge appear in both training and testing data. Model performance will be evaluated using measures such as accuracy, precision, recall, and a confusion matrix.
#v(0.5em)
In addition to predicting bridge condition, the study will examine which predictor variables are most useful for distinguishing between Good, Fair, and Poor bridges. For example, the analysis can evaluate whether bridge age, traffic demand, structural material, bridge dimensions, or other characteristics provide important information for predicting condition. The purpose is not to establish that these variables directly cause deterioration, but to identify patterns and characteristics associated with bridge condition.
#v(0.5em)
This analysis is expected to be useful because transportation agencies must determine where limited inspection, maintenance, and rehabilitation resources should be directed. If existing bridge characteristics can help identify bridges that are more likely to be in poorer condition, predictive models may provide additional information to support maintenance planning. The results could therefore contribute to a more data-driven approach for prioritizing bridge maintenance and rehabilitation activities.

= Team Plan
The project work will be divided among team members while major decisions and final results will be reviewed together. One part of the team will focus on data preparation and cleaning, including checking missing values, selecting appropriate predictor variables, and organizing repeated bridge records across years. Another part will focus on exploratory data analysis and visualization to examine patterns between bridge characteristics and condition. The remaining work will focus on predictive model development and evaluation, including training classification models and assessing their performance.
#v(0.5em)
All team members will contribute to interpreting the results, reviewing the analysis and code, preparing figures and tables, and writing and editing the final report. This approach will allow each team member to contribute to both the technical analysis and the final presentation of the project.

= Exploratory Data Analysis
== Analysis Workflow and Data Quality
The export is comma-delimited with single-quoted text fields, including some categories containing commas. It is read with a single-quote text delimiter to preserve all columns without discarding malformed-looking lines. Identifiers remain strings to retain leading zeros. Numeric conversion is checked for unexpected parsing failures. Blank categories are treated as missing, the study period is restricted to 2002--2025, and the bridge-year key is checked for duplicates. Reported age agrees with reporting year minus year built for all 580,971 nonmissing ages.

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

    [Number of spans], [1], [<0.01%],

  ),

  caption: [Raw missingness in the 582,165 retained observations. All remaining exported fields have zero blank entries; coded zeros and invalid counts are audited separately.],

) <missing>

Span counts contain 18 negative and 1,035 zero values, in addition to one blank. Nonpositive span counts are flagged and set to missing for valid-count summaries and planned model inputs. Their original values remain available in the source data. Traffic contains 755 zeros; these are retained and flagged because the export alone does not establish whether they represent no traffic or a reporting issue. Maximum span and deck area contain 1,866 and 38 zeros, respectively; these require interpretation before use as physical measurements.

Deck width needs special treatment: 72,503 records have width zero, and 71,995 of these (99.30%) are coded as culverts. FHWA documents zero deck-width coding for culverts, structures under fill, and structures without structural decks @fhwa_condition. Therefore, width zeros are not automatically treated as erroneous or used to exclude culverts. Planned preprocessing will retain a zero-width indicator, preserve design type, and distinguish positive measured width from this coding pattern. Extreme positive dimensions are retained for EDA and flagged for review rather than removed using an arbitrary cutoff.

== Numeric Distributions
@summary reports numerical characteristics using available observations. Traffic and bridge dimensions are right-skewed in this sample. ADT has a median of 309 vehicles/day, a mean of 5,257, and a maximum of 590,800. Deck area has a median of 1,946 sq. ft. compared with a mean of 5,425 sq. ft. These differences support using medians and interquartile ranges alongside means, and considering logarithmic transformations for traffic and positive geometric variables.

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
The age distributions differ substantially across classes (@age-fig). Median ages are 24, 47, and 57 years for Good, Fair, and Poor observations, respectively; their means are 27.33, 50.63, and 64.54 years. Among labeled records with known age, the proportion classified Poor rises from 0.21% for ages 0--19 to 2.21% for 20--39, 8.77% for 40--59, 11.31% for 60--79, and 20.17% for 80 or older. These are within-band percentages, not shares of all Poor bridges.

#figure(image("figures/02_age.svg", width: 100%), caption: [(a) Age by condition; boxes show quartiles, center lines show medians, and whiskers extend to the last observation within 1.5 interquartile ranges. Outlier points are hidden for readability, but retained in the statistics. (b) Poor-condition percentage within each age band. Both panels use 580,652 records with known condition and age. Older observations have higher Poor prevalence in this sample.]) <age-fig>

These results support age as a candidate predictor, but they do not isolate a causal age effect. A bridge can appear repeatedly, and age can be associated with material, design, rehabilitation, and reporting period. The distributions also overlap. Consequently, age alone will not be assumed to determine condition, and no significance tests treating all bridge-year rows as independent are reported.

== Material and Structural Characteristics
@material-fig compares class composition within the six most common material categories and a pooled smaller-material category. The Poor percentage is 13.93% for Steel, 6.77% for Steel Continuous, 5.89% for Concrete, and 3.32% for Prestressed Concrete. Continuous Concrete and Continuous Prestressed Concrete have Poor shares of 2.82% and 2.01%, respectively. Material categories use the export's labels; continuous and noncontinuous types are kept separate.

#figure(image("figures/03_material.svg", width: 100%), caption: [Condition percentages within material groups. Labels give labeled bridge-year counts. The six largest raw material groups are shown separately; smaller groups are pooled. The 193 labeled records with missing material are omitted from this figure. Unadjusted material differences motivate multivariable analysis rather than a causal ranking of materials.]) <material-fig>

The largest design categories are Box Beam or Girders - Multiple (202,962 observations), Stringer/Multi-beam or Girder (167,672), and Culvert (104,985). These design counts include records without a condition label. Together with the width audit, this mix shows that the dataset includes substantially different structural configurations. Material and design should therefore enter the model as categorical predictors. Unadjusted material differences may reflect age, design, ownership, and exposure differences, so they do not establish that any material intrinsically deteriorates faster.

== Traffic and Geometric Characteristics
Traffic distributions overlap across classes (@traffic-fig). Median ADT is 225 vehicles/day for Good, 650 for Fair, and 350 for Poor observations. Thus, the median does not increase monotonically from Good to Poor. Traffic remains a plausible complementary predictor, but this EDA does not support a simple claim that higher traffic alone implies poorer condition. The figure uses a log10(1 + ADT) scale and retains traffic zeros.

#figure(image("figures/04_traffic.svg", width: 100%), caption: [ADT by condition on a log10(1 + ADT) scale, with tick labels expressed in vehicles/day. Box and whisker conventions match @age-fig; outlier points are hidden. The 581,785 labeled observations show substantial overlap and a nonmonotonic ordering of class medians.]) <traffic-fig>

Median structure lengths are 62.0, 76.1, and 72.2 ft for Good, Fair, and Poor, respectively. Median deck areas are 1,811, 2,334, and 2,057 sq. ft. These contrasts likewise do not follow a monotonic class ordering. Geometry may add information in combination with age and design, but redundant geometric predictors and the coding of culverts will need attention when interpreting model importance.

== Reporting-Year Patterns and Data Limitations
The share of labeled records classified Good decreases from 70.91% in 2002 to 44.61% in 2025, while the Poor share increases from 3.58% to 9.52% (@time-fig(a)). The annual labeled sample grows from 20,724 to 26,927. These curves describe the supplied cohort and its changing observed composition; they do not establish statewide causal deterioration rates. All 26,927 grouping identifiers occur in 2025. Combined with InfoBridge's current-submittal selection behavior @fhwa_infobridge, this is consistent with historical records linked to the selected 2025 inventory. It should not be assumed to include bridges retired before 2025 or the complete historical Illinois inventory.

#figure(image("figures/05_time.svg", width: 100%), caption: [(a) Annual condition shares, with each year's labeled bridge-year count as denominator. (b) Truck-share missingness among all retained records in each year. Annual class composition changes while missingness drops sharply in 2013, motivating reporting-year sensitivity analysis and careful missing-value treatment.]) <time-fig>

Truck-share missingness averages 33.41% during 2002--2012 but only 0.05% during 2013--2025 (@time-fig(b)). The reason for this discontinuity is not established by the supplied file. Deleting every incomplete row would leave 494,364 observations and disproportionately remove early-period data. For modeling, predictor missingness will instead be handled within the training pipeline, with a sensitivity analysis excluding truck share. Missingness indicators will be interpreted cautiously because they may encode reporting practices rather than structural condition.

The analysis is descriptive and observation-weighted: bridges recorded for more years contribute more rows. It is neither bridge-equal-weighted nor deck-area-weighted, and these percentages should not be presented as official statewide performance measures. Maintenance histories, environmental exposure, and component ratings are unavailable in this export. These limitations constrain causal interpretation, prediction of individual deterioration trajectories, and generalization beyond the selected Illinois cohort.

= Predictive Modeling
== Task, Features, and Practical Use
Deliverable 3 will compare models for the recorded Good/Fair/Poor class in the same reporting year. A successful model could support retrospective screening and identify inventory characteristics associated with condition, but should supplement inspection information rather than determine maintenance decisions alone. No trained-model performance is claimed in this deliverable.

Candidate inputs are age, ADT, truck share, owner agency, material, design, span count, structure length, maximum span, deck width, deck area, and reporting year. Historical and 2025 structure identifiers are excluded as predictors; the latter is retained only for grouping. Constant state fields are excluded. Year Built is omitted when age and reporting year are present because it is algebraically redundant with them. Target-derived component ratings will not be introduced as inputs. A model excluding reporting year will be compared to assess reliance on period-specific patterns.

== Preprocessing and Candidate Models
After group assignment, all learned preprocessing will be fitted using training data only. Invalid span counts will become missing. Numeric missing values will receive training-set medians and explicit missing indicators; missing categorical values will form an Unknown category. Categories will be one-hot encoded with unseen categories handled safely. Zero-width coding will be retained as an indicator, with positive width represented separately and conditional on design; other nonpositive geometric measurements will be flagged and treated as unavailable where physically inappropriate. Traffic zeros will be retained with a separate indicator. Log1p transformations will be considered for ADT and positive size variables, with continuous inputs standardized for logistic regression. No information will be carried backward from later records to fill earlier missing measurements.

The first comparator will predict the most frequent training class. A regularized multinomial logistic regression will provide a relatively transparent baseline. A random forest will then test whether nonlinear relationships and interactions improve classification. Class weighting will be considered for both models because Poor represents only 5.45% of the labeled sample. Regularization, tree depth, minimum leaf size, and weighting choices will be selected on the validation set. Model complexity will be limited to choices feasible for this tabular dataset.

== Grouped Validation and Evaluation
The primary evaluation will hold out entire bridges to assess transfer to bridges unseen during training. A reproducible proposed split uses the 2025 structure identifier, seed 492, and approximate proportions of 60% training, 20% validation, and 20% test bridges. Bridge groups are stratified by their latest available nonmissing class, used only to balance group assignment. All annual records of a bridge remain in its assigned partition. The supplied manifest allocates 16,156 bridges and 348,774 labeled rows to training; 5,385 bridges and 116,575 rows to validation; and 5,386 bridges and 116,436 rows to testing. These are prepared partitions, not model results.

The held-out test set will be used once after selecting the pipeline and model. Macro-F1 will be the primary comparison metric, accompanied by balanced accuracy, overall accuracy, precision/recall/F1 for each class, and a confusion matrix. Poor recall will quantify missed Poor observations, while Poor precision will characterize false alarms. If uncertainty intervals are reported, resampling will occur at the bridge-group level rather than independently across annual rows.

This grouped evaluation does not test future-year forecasting, because records from overlapping reporting years are present across groups. As a separate robustness check, a chronological evaluation can train on 2002--2018, validate on 2019--2021, and test on 2022--2025. Allowing a bridge to recur in that chronological design addresses later-year classification for known bridges and must be reported as a different estimand. A future deterioration forecast would additionally require a defined horizon and correctly aligned future targets, which are outside the current classification plan.


== Interpretation and Sensitivity Analyses
Planned comparisons will examine the effect of removing truck share, excluding reporting year, and restricting analysis to nonculvert structures. Per-class metrics will be checked across reporting periods and major material groups where sample sizes permit. Predictor importance will be assessed on validation data through permutation of original feature groups, so a categorical variable's encoded columns are assessed together. Age, reporting year, and dimensions may share predictive information; rankings will therefore be described as model-dependent associations rather than causal effects.

= Team Plan

The project work will be divided among team members while major decisions and final results will be reviewed together. One part of the team will focus on data preparation and cleaning, including checking missing values, selecting appropriate predictor variables, and organizing repeated bridge records across years. Another part will focus on exploratory data analysis and visualization to examine patterns between bridge characteristics and condition. The remaining work will focus on predictive model development and evaluation, including training classification models and assessing their performance.

#v(0.5em)

All team members will contribute to interpreting the results, reviewing the analysis and code, preparing figures and tables, and writing and editing the final report. This approach will allow each team member to contribute to both the technical analysis and the final presentation of the project.

Project work is organized around data preparation and validity checks, exploratory visualization, predictive modeling, and report integration. The team will jointly review the cross-year identifier mapping, preprocessing rules, split assignments, model results, and final interpretation. Each member will contribute analysis or report changes through the shared GitHub repository, with code and figures reviewed together before final submission.