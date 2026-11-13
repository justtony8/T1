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
  index-terms: ("bridge condition", "National Bridge Inventory", "classification", "machine learning"),
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


#figure(image("figures/04_traffic.svg", width: 100%), caption: [ADT by condition on a log10(1 + ADT) scale, with tick labels expressed in vehicles/day. Box and whisker conventions match @age-fig; outlier points are hidden. The 581,785 labeled observations show substantial overlap and a nonmonotonic ordering of class medians.]) <traffic-fig>

Median structure lengths are 62.0, 76.1, and 72.2 ft for Good, Fair, and Poor, respectively. Median deck areas are 1,811, 2,334, and 2,057 sq. ft.

These contrasts likewise do not follow a monotonic class ordering. Geometry may add information in combination with age and design, but redundant geometric predictors and the coding of culverts will need attention when interpreting model importance.

== Reporting-Year Patterns and Data Limitations
The share of labeled records classified Good decreases from 70.91% in 2002 to 44.61% in 2025, while the Poor share increases from 3.58% to 9.52% (@time-fig(a)). The annual labeled sample grows from 20,724 to 26,927. These curves describe the supplied cohort and its changing observed composition; they do not establish statewide causal deterioration rates. All 26,927 grouping identifiers occur in 2025. Combined with InfoBridge's current-submittal selection behavior @fhwa_infobridge, this is consistent with historical records linked to the selected 2025 inventory. It should not be assumed to include bridges retired before 2025 or the complete historical Illinois inventory.

#figure(image("figures/05_time.svg", width: 100%), caption: [(a) Annual condition shares, with each year's labeled bridge-year count as denominator. (b) Truck-share missingness among all retained records in each year. Annual class composition changes while missingness drops sharply in 2013, motivating reporting-year sensitivity analysis and careful missing-value treatment.]) <time-fig>

Truck-share missingness averages 33.41% during 2002--2012 but only 0.05% during 2013--2025 (@time-fig(b)). The reason for this discontinuity is not established by the supplied file. Deleting every incomplete row would leave 494,364 observations and disproportionately remove early-period data. For modeling, predictor missingness will instead be handled within the training pipeline, with a sensitivity analysis excluding truck share. Missingness indicators will be interpreted cautiously because they may encode reporting practices rather than structural condition.

The analysis is descriptive and observation-weighted: bridges recorded for more years contribute more rows. It is neither bridge-equal-weighted nor deck-area-weighted, and these percentages should not be presented as official statewide performance measures. Maintenance histories, environmental exposure, and component ratings are unavailable in this export. These limitations constrain causal interpretation, prediction of individual deterioration trajectories, and generalization beyond the selected Illinois cohort.

= Predictive Modeling


== Task, Features, and Practical Use

In this study, we used multinomial logistic regression to classify bridge conditions into three groups: Good, Fair, and Poor, using Illinois National Bridge Inventory (NBI) data from 2002 to 2025. Our goal was to examine whether bridge information could help predict bridge conditions, with particular attention to identifying bridges in Poor condition. The model used several features, including bridge age, daily traffic, truck traffic percentage, owner agency, main span material and design, number of spans, structure length, maximum span length, deck width, deck area, and reporting year. We did not use bridge identification numbers as predictive features because they do not represent physical bridge characteristics. Instead, these identifiers were used to group records belonging to the same bridge. Year built was also excluded because it can be calculated using bridge age and reporting year.

#v(0.5em)

The model was developed to predict the bridge condition recorded in the same reporting year, rather than forecasting how bridge conditions may change in the future. The predicted condition categories could potentially support preliminary maintenance screening and help transportation agencies identify bridges that may require additional inspections. However, the predictions should be used as supplementary information rather than replacing engineering inspections or directly determining maintenance priorities.

== Data Preprocessing and Model Development

The initial dataset contained 582,165 bridge-year observations from 2002 to 2025. After excluding 380 observations with missing bridge condition labels, 581,785 labeled observations remained for supervised learning. Before model training, missing numerical values were replaced using medians calculated from the training dataset, while missing categorical values were assigned an Unknown category. Categorical predictors, including owner agency, main span material, and main span design, were converted into numerical features through one-hot encoding. Selected continuous variables, including average daily traffic, structure length, maximum span length, and deck area, were transformed using log(1+x). Numerical predictors were then standardized using means and standard deviations calculated from the training data.

#v(0.5em)

Invalid span counts and nonpositive geometric measurements were treated as missing where physically inappropriate. Zero-width coding was retained through a separate indicator to account for culverts and other structures without conventional deck-width measurements. Additional indicators were included for missing numerical values and zero traffic observations. These preprocessing procedures were applied consistently to the training, validation, and test datasets, while all learned preprocessing parameters were determined using training data only.

#v(0.5em)

A multinomial logistic regression classifier with L2 regularization was implemented in Julia using MLJ and MLJLinearModels. Multinomial logistic regression was selected because the prediction target consists of three categories, Good, Fair, and Poor, and the method provides a relatively simple and interpretable classification framework. Three regularization parameters (lambda = 0.01, 0.1, and 1.0) were evaluated to identify the best-performing model based on validation macro-F1.

== Grouped Validation and Model Selection

To prevent data leakage between training and testing, observations were divided at the bridge level rather than at the individual record level. The 2025 NBI structure identifier was used to group repeated observations of the same bridge. Bridge groups were stratified according to their latest available nonmissing condition category. A fixed random seed of 492 was used to obtain reproducible assignments, with approximately 60% of bridges allocated to training, 20% to validation, and 20% to testing. As shown in @model-split-table, the training dataset contained 348,406 observations from 16,156 bridges, while the validation and test datasets contained 116,534 and 116,845 observations, respectively. All records belonging to the same bridge were assigned to the same partition.

#figure(
  table(
    columns: (1.2fr, 0.9fr, 1.2fr, 0.9fr),
    align: (left, right, right, right),
    table.header(
      [*Dataset*],
      [*Bridges*],
      [*Observations*],
      [*Share*],
    ),
    [Training], [16,156], [348,406], [59.89%],
    [Validation], [5,385], [116,534], [20.03%],
    [Test], [5,386], [116,845], [20.08%],
    [*Total*], [*26,927*], [*581,785*], [*100%*],
  ),
  caption: [Distribution of bridges and labeled bridge-year observations across training, validation, and test datasets.]
) <model-split-table>

#v(0.5em)

The validation dataset was used to compare three regularization parameters. Macro-averaged F1 was selected as the primary model selection metric because the dataset exhibited substantial class imbalance, with Poor-condition observations representing only 5.45% of the labeled dataset. Unlike overall accuracy, macro-F1 gives equal importance to each condition category, making it more appropriate for evaluating classification performance when one category is much less frequent than the others. The validation results for the three regularization parameters are presented in @model-validation-table.

#figure(
  table(
    columns: (0.7fr, 1fr, 1fr, 1.2fr, 0.9fr),
    align: center,
    table.header(
      [*Lambda*],
      [*Accuracy*],
      [*Macro-F1*],
      [*Balanced Accuracy*],
      [*Poor Recall*],
    ),
    [0.01], [0.7062], [0.4599], [0.4699], [0.0000],
    [0.1], [0.7036], [0.4576], [0.4674], [0.0000],
    [1.0], [0.6713], [0.4316], [0.4414], [0.0000],
  ),
  caption: [Validation performance of multinomial logistic regression under different regularization parameters.]
) <model-validation-table>

#v(0.5em)

The model with lambda = 0.01 achieved the highest validation macro-F1 score of 0.4599 and an accuracy of 70.62%. Therefore, lambda = 0.01 was selected for the final test evaluation. Increasing lambda from 0.01 to 1.0 reduced both accuracy and macro-F1 within the tested range. However, Poor-class recall remained zero for all three parameter settings, indicating that modifying the regularization strength alone did not resolve the model's difficulty in identifying Poor-condition bridges.

== Model Performance and Evaluation

The selected multinomial logistic regression model was evaluated on the held-out test dataset containing 116,845 bridge-year observations. The model achieved an overall accuracy of 70.53%, a macro-F1 score of 0.4604, and a balanced accuracy of 47.12%, correctly classifying a total of 82,406 observations. Although the overall accuracy exceeded 70%, the model showed substantial differences in predictive performance across the three condition categories. As summarized in @model-class-table, Good-condition bridges achieved the highest recall of 88.07% and an F1 score of 0.8029, indicating that most Good observations were correctly identified. Fair-condition bridges achieved a recall of 53.30% and an F1 score of 0.5783, suggesting that the model had greater difficulty distinguishing Fair observations from other categories. The most significant limitation was observed for Poor-condition bridges, for which both recall and F1 were zero.

#figure(
  table(
    columns: (1fr, 1fr, 1fr, 0.9fr, 1fr),
    align: (left, center, center, center, right),
    table.header(
      [*Condition*],
      [*Precision*],
      [*Recall*],
      [*F1*],
      [*Support*],
    ),
    [Good], [0.7377], [0.8807], [0.8029], [67,839],
    [Fair], [0.6321], [0.5330], [0.5783], [42,514],
    [Poor], [0.0000], [0.0000], [0.0000], [6,492],
  ),
  caption: [Class-specific classification performance of the selected multinomial logistic regression model on the held-out test dataset.]
) <model-class-table>

#v(0.5em)

The confusion matrix in @model-confusion-fig provides additional information about the classification errors. Among the 6,492 actual Poor observations, 1,388 were incorrectly predicted as Good, while 5,104 were predicted as Fair. None of the Poor observations were correctly identified. The model predicted only ten observations as Poor, but all ten predictions were incorrect. These results demonstrate that the classifier strongly favored Good and Fair predictions and was unable to identify the minority Poor category, despite achieving relatively high overall accuracy.

#figure(
  image("model_results/confusion_matrix.png", width: 100%),
  caption: [Confusion matrix for the selected multinomial logistic regression model on the held-out test dataset. Rows represent actual conditions and columns represent predicted conditions.]
) <model-confusion-fig>

#v(0.5em)

The differences in classification performance are further illustrated in @model-f1-fig, which compares the F1 scores for Good, Fair, and Poor conditions. Good achieved the highest F1 score of 0.8029, followed by Fair at 0.5783, while Poor had an F1 score of zero. These findings indicate that overall accuracy alone does not adequately describe the model's ability to identify different condition categories. In particular, the model was unable to identify any observations belonging to the most critical condition category, which substantially limits its usefulness for maintenance screening.

#figure(
  image("model_results/per_class_f1.png", width: 100%),
  caption: [Comparison of class-specific F1 scores for Good, Fair, and Poor bridge conditions on the held-out test dataset.]
) <model-f1-fig>

== Discussion and Limitations

The multinomial logistic regression model identified Good-condition bridges more reliably than Fair-condition bridges and missed every Poor-condition bridge in the evaluation (0% recall). Overall accuracy was 70.53%. Averaging recall across the three classes gave a balanced accuracy of 47.12%. For maintenance planning, a Poor-condition bridge classified as Good or Fair could be overlooked when agencies prioritize inspections or repairs.Class imbalance may partly explain why the model missed the Poor bridges. They accounted for just 5.45% of the labeled records, compared with 36.35% for Fair and 58.20% for Good. The model gave each observation equal weight during training, so the small number of Poor observations may have had limited influence on the fit.
#v(0.5em)
The model may also have missed nonlinear relationships and interactions among bridge characteristics. For example, the relationship between age and condition may vary with structural material, bridge design, or traffic demand. The model did not include terms for those interactions. The NBI data used in this analysis also lacked detailed maintenance histories, environmental exposure measurements, and component-level condition ratings that could help explain differences in deterioration.
#v(0.5em)
A next step would be to test whether class weighting improves recall for Poor-condition bridges. Adding interactions among age, structural material, and bridge geometry could help capture some of the relationships the current model misses. A comparison with a random forest could also show whether a more flexible model performs better. Sensitivity analyses could assess how the results change when truck traffic percentage, reporting year, or culvert structures are excluded.The current model provides a baseline for these comparisons. Before its predictions can inform maintenance priorities, further validation would need to show that Poor-condition bridges can be identified reliably.


= Team Plan

Project work will be divided among data preparation and validity checks, exploratory analysis and visualization, predictive modeling and evaluation, and report integration. Team members will organize repeated bridge records, define preprocessing and predictor rules, examine condition patterns, train and evaluate classification models, and integrate the results into the report.

#v(0.5em)

All team members will interpret results, review analyses and code, prepare figures and tables, and edit the final report. The team will jointly review the cross-year identifier mapping, preprocessing rules, split assignments, model results, and final interpretation. Contributions will be managed through the shared GitHub repository, with code, figures, and text reviewed before submission.
