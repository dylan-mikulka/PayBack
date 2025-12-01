-- PAYBACK DATABASE - SQL QUERIES
-- CS3200 Final Project
-- Dylan Mikulka, Malia Wanderer, Shahid Shaikh, Ansh Aggarwal

USE payback;

-- Query 1: Who paid the most in each group?
-- We need this to see who's covering most expenses in each group

SELECT 
    g.name AS group_name,
    CONCAT(u.first_name, ' ', u.last_name) AS top_spender,
    SUM(e.amount) AS total_paid
FROM Expenses e
JOIN `Groups` g ON e.group_id = g.group_id
JOIN Users u ON e.paid_by_user_id = u.user_id
GROUP BY g.group_id, g.name, u.user_id, u.first_name, u.last_name
HAVING SUM(e.amount) = (
    SELECT MAX(group_total)
    FROM (
        SELECT e2.group_id, e2.paid_by_user_id, SUM(e2.amount) AS group_total
        FROM Expenses e2
        WHERE e2.group_id = g.group_id
        GROUP BY e2.group_id, e2.paid_by_user_id
    ) AS subquery
)
ORDER BY total_paid DESC;


-- Query 2: Net balance for each user
-- positive = people owe them, negative = they owe money
-- had to use two separate subqueries for credits vs debts

SELECT 
    CONCAT(u.first_name, ' ', u.last_name) AS user_name,
    COALESCE(owed_to.total, 0) AS total_owed_to_them,
    COALESCE(they_owe.total, 0) AS total_they_owe,
    COALESCE(owed_to.total, 0) - COALESCE(they_owe.total, 0) AS net_balance,
    CASE 
        WHEN COALESCE(owed_to.total, 0) - COALESCE(they_owe.total, 0) > 0 
        THEN 'Net Creditor'
        ELSE 'Net Debtor'
    END AS status
FROM Users u
LEFT JOIN (
    SELECT creditor_user_id, SUM(amount) AS total
    FROM Debts
    GROUP BY creditor_user_id
) owed_to ON u.user_id = owed_to.creditor_user_id
LEFT JOIN (
    SELECT debtor_user_id, SUM(amount) AS total
    FROM Debts
    GROUP BY debtor_user_id
) they_owe ON u.user_id = they_owe.debtor_user_id
WHERE COALESCE(owed_to.total, 0) > 0 OR COALESCE(they_owe.total, 0) > 0
ORDER BY net_balance DESC;


-- Query 3: Groups with most outstanding debt
-- helps see which groups need to settle up

SELECT 
    g.name AS group_name,
    g.category,
    COUNT(d.debt_id) AS number_of_debts,
    SUM(d.amount) AS total_outstanding_debt,
    COUNT(DISTINCT d.debtor_user_id) AS people_who_owe_money
FROM `Groups` g
JOIN Debts d ON g.group_id = d.group_id
GROUP BY g.group_id, g.name, g.category
ORDER BY total_outstanding_debt DESC;


-- Query 4: Settlement progress per group
-- comparing how much debt exists vs how much has been paid back

SELECT 
    g.name AS group_name,
    COALESCE(debt_totals.total_debt, 0) AS total_debt,
    COALESCE(settlement_totals.total_settled, 0) AS total_settled,
    ROUND(
        COALESCE(settlement_totals.total_settled, 0) / 
        NULLIF(COALESCE(debt_totals.total_debt, 0), 0) * 100, 
        1
    ) AS percent_settled
FROM `Groups` g
LEFT JOIN (
    SELECT group_id, SUM(amount) AS total_debt
    FROM Debts
    GROUP BY group_id
) debt_totals ON g.group_id = debt_totals.group_id
LEFT JOIN (
    SELECT group_id, SUM(amount) AS total_settled
    FROM Settlements
    GROUP BY group_id
) settlement_totals ON g.group_id = settlement_totals.group_id
ORDER BY percent_settled DESC;


-- Query 5: Roommate debt breakdown
-- specifically for the apartment rent/utilities group
-- shows who owes who for the housing expenses

SELECT 
    CONCAT(debtor.first_name, ' ', debtor.last_name) AS roommate_who_owes,
    CONCAT(creditor.first_name, ' ', creditor.last_name) AS roommate_owed_money,
    d.amount AS amount_owed
FROM Debts d
JOIN Users debtor ON d.debtor_user_id = debtor.user_id
JOIN Users creditor ON d.creditor_user_id = creditor.user_id
JOIN `Groups` g ON d.group_id = g.group_id
WHERE g.category = 'housing'
ORDER BY d.amount DESC;


-- Query 6: Where is money being spent?
-- breaks down expenses by category to see spending patterns

SELECT 
    category,
    COUNT(*) AS number_of_transactions,
    SUM(amount) AS total_spent,
    ROUND(AVG(amount), 2) AS average_expense,
    MIN(amount) AS smallest_expense,
    MAX(amount) AS largest_expense
FROM Expenses
GROUP BY category
ORDER BY total_spent DESC;


-- Query 7: Find users in multiple groups together
-- useful to see which people hang out/split expenses together the most
-- self-join on GroupMembers to find overlaps

SELECT 
    CONCAT(u1.first_name, ' ', u1.last_name) AS user_1,
    CONCAT(u2.first_name, ' ', u2.last_name) AS user_2,
    COUNT(DISTINCT gm1.group_id) AS shared_groups,
    GROUP_CONCAT(DISTINCT g.name SEPARATOR ', ') AS group_names
FROM GroupMembers gm1
JOIN GroupMembers gm2 ON gm1.group_id = gm2.group_id 
    AND gm1.user_id < gm2.user_id
JOIN Users u1 ON gm1.user_id = u1.user_id
JOIN Users u2 ON gm2.user_id = u2.user_id
JOIN `Groups` g ON gm1.group_id = g.group_id
GROUP BY u1.user_id, u2.user_id, u1.first_name, u1.last_name, 
         u2.first_name, u2.last_name
HAVING COUNT(DISTINCT gm1.group_id) > 1
ORDER BY shared_groups DESC;


-- Query 8: What does Ansh owe? (personal dashboard example)
-- this would be the kind of query a user sees when they log in

SELECT 
    g.name AS group_name,
    CONCAT(creditor.first_name, ' ', creditor.last_name) AS you_owe,
    d.amount AS amount
FROM Debts d
JOIN `Groups` g ON d.group_id = g.group_id
JOIN Users creditor ON d.creditor_user_id = creditor.user_id
WHERE d.debtor_user_id = 4  -- Ansh 
ORDER BY d.amount DESC;


-- Query 9: Settlement optimization - how many transactions can we save?
-- shows the value of our optimization algorithm
-- current transactions vs minimum needed (n-1 where n = people with balance)

SELECT 
    g.name AS group_name,
    (SELECT COUNT(*) FROM Debts WHERE group_id = g.group_id) 
        AS current_transactions_needed,
    (SELECT COUNT(DISTINCT user_id) 
     FROM (
         SELECT debtor_user_id AS user_id FROM Debts WHERE group_id = g.group_id
         UNION
         SELECT creditor_user_id AS user_id FROM Debts WHERE group_id = g.group_id
     ) AS all_users) - 1 
        AS optimized_transactions_needed,
    (SELECT COUNT(*) FROM Debts WHERE group_id = g.group_id) - 
    (SELECT COUNT(DISTINCT user_id) 
     FROM (
         SELECT debtor_user_id AS user_id FROM Debts WHERE group_id = g.group_id
         UNION
         SELECT creditor_user_id AS user_id FROM Debts WHERE group_id = g.group_id
     ) AS all_users2) + 1 
        AS transactions_saved
FROM `Groups` g
WHERE EXISTS (SELECT 1 FROM Debts WHERE group_id = g.group_id)
ORDER BY transactions_saved DESC;


-- Query 10: Monthly spending trends
-- when do groups spend the most? useful for seeing patterns over time

SELECT 
    DATE_FORMAT(expense_date, '%Y-%m') AS month,
    COUNT(*) AS number_of_expenses,
    COUNT(DISTINCT group_id) AS groups_with_expenses,
    SUM(amount) AS total_spent,
    ROUND(AVG(amount), 2) AS average_expense
FROM Expenses
GROUP BY DATE_FORMAT(expense_date, '%Y-%m')
ORDER BY month;
