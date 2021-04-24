# Insurance DB Project
SQL query to find overdue claims. A claim is considered late if a ReservingTool publish is needed.


Background:
An examiner is assigned a claim and has to publish on the Reserve Tool within 14 days of being assigned the claim or 90 days since the last published date, whichever is larger.


Goal:
Determine for each claim number the number of days until a claim requires a new publication on the reserving tool and, if applicable, the number of days that claim is overdue. 


Result:
A query executed by stored procedure SPGetOutstandingRTPublish. The query shows for each claim number the information about the personnel reviewing the claim, information about the claimant, claim status, number of days since last reserving tool publish, number of days left to complete a publish on reserving tool, and number of days overdue. 


How Claims Are Filtered:
Claims are filtered to exclude claims handled outside of Sacramento, San Francisco, and San Diego. Claims where the reserve type is Fatality are excluded. Reopened claims where the ReopenedReasonID is 3 are excluded. Additional claims are filtered based on the aggregated reserve amounts in the reserve buckets. Of the roughly 30 Reserve types in the table, there are only 6 reserve buckets indicated by the ParentID which will match a reserve bucket (Medical, Temporary Disability, Permanent Disability, Vocational Rehabilitation, Expense, Fatality). 


Days To Complete Calculation:
For example, If a claim was assigned 10 days ago (4 days to 14) and has not been published for 75 days (15 to 90), this claim would have 15 more days before another publication on the reserving tool table is necessary. If claim last publish date is null, use only the assigned date rule (14 days til publish is needed). 


Challenges:
1. Messy data -- inconsistent PKs
2. Claimants and Patients relationship
3. Reserve Type table having 30 distinct reserve type descriptions, but they all belong to only 6 reserve buckets determined by the ParentID field.
4. Case statements for reserve types and number of days to complete publication


Improvements:
1. Connect to a graphic interface / dashboard that updates after set interval showing:
* Top performers based on lowest % of overdue claims
* % of claims that are on time/late for entire company
* Total number of days overdue for entire company
