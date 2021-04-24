USE Insurance
GO

CREATE PROCEDURE SPGetOutstandingRTPublish (
    @DaysToComplete AS INT = NULL
    , @DaysOverdue AS INT = NULL
    , @Office AS VARCHAR(31) = NULL
    , @ManagerCode AS VARCHAR(31) = NULL
    , @SupervisorCode AS VARCHAR(31) = NULL
    , @ExaminerCode AS VARCHAR(31) = NULL
    , @Team AS VARCHAR(31) = NULL
    , @ClaimsWithoutRTPublish AS BIT = 0
)
AS
BEGIN

    DECLARE @DateAsOf DATE
    SET @DateAsOf = '1/1/2019'

    DECLARE @ReservingToolPbl TABLE
    (
        Claimnumber VARCHAR(30)
        , LastPublishedDate DATETIME 
    )

    DECLARE @AssignedDateLog TABLE
    (
        PK INT
        , ExaminerAssignedDate DATETIME 
    )

    INSERT INTO @ReservingToolPbl
    SELECT ClaimNumber,
        MAX(EnteredOn) AS LastPublishedDate
    FROM ReservingTool
    WHERE IsPublished = 1
    GROUP BY ClaimNumber

    INSERT INTO @AssignedDateLog
    SELECT PK, 
        MAX(EntryDate) AS ExaminerAssignedDate
    FROM ClaimLog CL
    WHERE FieldName = 'ExaminerCode'
    GROUP BY PK

    --SELECT * FROM @ReservingToolPbl
    --SELECT * FROM @AssignedDateLog

    SELECT *
    FROM 
        (
        SELECT ClaimNumber
            , ManagerCode 
                , ManagerTitle
                , ManagerName
                , SupervisorCode
                , SupervisorTitle
                , SupervisorName
                , ExaminerCode
                , ExaminerTitle
                , ExaminerName
                , Office
                , ClaimStatusDesc
                , ClaimaintName
                , ClaimantTypeDesc
                , ExaminerAssignedDate
                , ReopenedDate
                , AdjustedAssignedDate
                , LastPublishedDate
                , DaysSinceAdjustedAssignedDate
                , DaysSinceLastPublishedDate
                , CASE WHEN DaysSinceAdjustedAssignedDate > 14 AND (DaysSinceLastPublishedDate > 90 OR DaysSinceLastPublishedDate IS NULL) THEN 0
                       WHEN 91 - DaysSinceLastPublishedDate >= 15 - DaysSinceAdjustedAssignedDate AND DaysSinceLastPublishedDate IS NOT NULL
                           THEN 91 - DaysSinceLastPublishedDate
                       ELSE 15 - DaysSinceAdjustedAssignedDate
                  END AS DaysToComplete
                , CASE WHEN DaysSinceAdjustedAssignedDate <= 14 OR (DaysSinceLastPublishedDate <= 90 AND DaysSinceLastPublishedDate IS NOT NULL) THEN 0
                       WHEN DaysSinceLastPublishedDate - 90 <= DaysSinceAdjustedAssignedDate - 14 AND DaysSinceLastPublishedDate IS NOT NULL
                           THEN DaysSinceLastPublishedDate - 90
                       ELSE DaysSinceAdjustedAssignedDate - 14
                  END AS DaysOverdue

        FROM
            (
            SELECT
                C.ClaimNumber
                , R. ReserveAmount
                , (CASE 
                   WHEN RT.ParentID IN (1,2,3,4,5) THEN RT.ParentID
                   ELSE RT.reserveTypeID
                   END) AS ReserveTypeBucketID  
                , O.OfficeDesc AS Office
                , U.UserName AS ExaminerCode
                , Users2.UserName AS SupervisorCode
                , Users3.UserName AS  ManagerCode
                , U.Title AS ExaminerTitle
                , Users2.Title AS SupervisorTitle
                , Users3.Title AS  ManagerTitle
                , U.LastFirstName AS ExaminerName
                , Users2.LastFirstName AS SupervisorName
                , Users3.LastFirstName AS  ManagerName
                , CS.ClaimStatusDesc
                , P.LastName + ', ' + TRIM(P.FirstName + ' ' + P.MiddleName) AS ClaimaintName
                , CL.ReopenedDate
                , CT.ClaimantTypeDesc
                , O.State
                , U.ReserveLimit  
                , ADL.ExaminerAssignedDate
                , CASE WHEN CS.ClaimStatusDesc = 'Re-Open' AND CL.ReopenedDate > ADL.ExaminerAssignedDate THEN CL.ReopenedDate
                    ELSE ADL.ExaminerAssignedDate
                    END AS AdjustedAssignedDate
                , RTP.LastPublishedDate
                , CASE WHEN CS.ClaimStatusDesc = 'Re-Open' AND CL.ReopenedDate > ADL.ExaminerAssignedDate 
                       THEN DATEDIFF(DAY, CL.ReopenedDate, @DateAsOf)
                       ELSE DATEDIFF(DAY, ADL.ExaminerAssignedDate, @DateAsOf)
                       END AS DaysSinceAdjustedAssignedDate
                , DATEDIFF(DAY, RTP.LastPublishedDate, @DateAsOf) AS DaysSinceLastPublishedDate

            FROM Claimant CL
            INNER JOIN Claim C ON C.ClaimID = CL.ClaimID
            INNER JOIN Users U ON U.UserName = C.ExaminerCode
            INNER JOIN Users Users2 ON U.Supervisor = Users2.UserName
            INNER JOIN Users Users3 ON Users2.Supervisor = Users3.UserName
            INNER JOIN Office O ON U.OfficeID = O.OfficeID
            INNER JOIN ClaimantType CT ON CT.ClaimantTypeID = CL.ClaimantTypeID
            INNER JOIN Reserve R ON R.ClaimantID = CL.ClaimantID
            LEFT JOIN ClaimStatus CS ON CS. ClaimStatusID = CL.claimStatusID
            LEFT JOIN ReserveType RT ON RT.reserveTypeID = R.ReserveTypeID
            LEFT JOIN Patient P ON P.PatientID = CL.PatientID
            INNER JOIN @AssignedDateLog ADL ON C.ClaimID = ADL.PK
            LEFT JOIN @ReservingToolPbl RTP ON RTP.Claimnumber = C.ClaimNumber

            WHERE O.OfficeDesc IN ('Sacramento','San Francisco', 'San Diego')
                AND (RT.ParentID IN (1,2,3,4,5) OR RT.reserveTypeID IN (1,2,3,4,5))
                AND (CS.ClaimStatusID = 1 OR (CS.ClaimStatusID = 2 AND Cl.ReopenedReasonID <> 3))
            --ORDER BY ClaimNumber
            ) BaseData 
            PIVOT
            (SUM(ReserveAmount)
            FOR ReserveTypeBucketID IN ([1],[2],[3],[4],[5])
            ) PivotTable
            WHERE PivotTable.ClaimantTypeDesc IN ('First Aid', 'Medical Only')
                OR
                    (PivotTable.Office = 'San Diego'
                        AND ISNULL([1],0) + ISNULL([2],0) + ISNULL([3],0) 
                            + ISNULL([4],0) + ISNULL([5],0) >= PivotTable.ReserveLimit)
                OR
                    (PivotTable.Office IN ('Sacramento', 'San Francisco')
                        AND (ISNULL([1],0) > 800 
                            OR ISNULL([5],0) > 100 
                            OR (ISNULL([2],0) > 0 OR ISNULL([3],0) > 0 OR ISNULL([4],0) > 0)
                            )
                    )
            ) MainQuery
        WHERE (@DaysToComplete IS NULL OR DaysToComplete <= @DaysToComplete)
            AND (@DaysOverdue IS NULL OR DaysOverdue <= @DaysOverdue)
            AND (@Office IS NULL OR Office = @Office)
            AND (@ManagerCode IS NULL OR ManagerCode = @ManagerCode)
            AND (@SupervisorCode IS NULL OR SupervisorCode = @SupervisorCode)
            AND (@ExaminerCode IS NULL OR ExaminerCode = @ExaminerCode)
            AND (@Team IS NULL OR ExaminerTitle LIKE '%' + @Team + '%'
                    OR SupervisorTitle LIKE '%' + @Team + '%'
                    OR ManagerTitle LIKE '%' + @Team + '%'
                )
            AND (@ClaimsWithoutRTPublish = 0 OR LastPublishedDate IS NULL)



END
/* EXAMPLE INPUT:

SPGetOutstandingRTPublish 
    NULL
    , NULL
    , NULL
    , NULL
    , 'qkemp'
    , NULL
    , 'Loss Control'
    , 0

*/