DROP DATABASE IF EXISTS payback;
CREATE DATABASE payback;
USE payback;
-- Table 1 (Users)
-- this stores all users of the PayBack app
CREATE TABLE Users (
	user_id INT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    created_date DATE NOT NULL,
    INDEX idx_email (email),
    INDEX idx_name (last_name, first_name)
);
-- Table 2 (Groups)
-- this stores the expense-sharing groups 
CREATE TABLE `Groups` (
	group_id INT PRIMARY KEY,
	name VARCHAR(100) NOT NULL,
	description TEXT,
	category VARCHAR(50),
	created_date DATE NOT NULL,
	INDEX idx_category (category),
	INDEX idx_created_date (created_date)
);
-- Table 3 (Group Members)
-- Links users to groups 
CREATE TABLE GroupMembers (
	member_id INT PRIMARY KEY,
    group_id INT NOT NULL,
    user_id INT NOT NULL,
    join_date DATE NOT NULL,
    FOREIGN KEY (group_id) REFERENCES `Groups`(group_id)
		ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES Users(user_id)
		ON DELETE CASCADE,
	UNIQUE KEY unique_group_user (group_id, user_id),
    INDEX idx_group (group_id),
    INDEX idx_user (user_id)
);
-- Table 4 (Expenses)
-- Stores all the expenses 
CREATE TABLE Expenses (
	expense_id INT PRIMARY KEY,
    group_id INT NOT NULL,
    paid_by_user_id INT NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    description VARCHAR(255) NOT NULL,
    category VARCHAR(50),
    expense_date DATE NOT NULL,
    created_date DATE NOT NULL,
    FOREIGN KEY (group_id) REFERENCES `Groups`(group_id)
		ON DELETE CASCADE,
    FOREIGN KEY (paid_by_user_id) REFERENCES Users(user_id)
		ON DELETE RESTRICT,
    CHECK (amount > 0),
    INDEX idx_group_expense (group_id),
    INDEX idx_paid_by (paid_by_user_id),
    INDEX idx_expense_date (expense_date),
    INDEX idx_category (category)
);
-- Table 5 (Debts)
-- Tracks who owes whom money after splitting expenses
CREATE TABLE Debts (
	debt_id INT PRIMARY KEY AUTO_INCREMENT, 
	group_id INT NOT NULL,
    debtor_user_id INT NOT NULL,
    creditor_user_id INT NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (group_id) REFERENCES `Groups`(group_id)
		ON DELETE CASCADE,
    FOREIGN KEY (debtor_user_id) REFERENCES Users(user_id)
		ON DELETE RESTRICT,
	FOREIGN KEY (creditor_user_id) REFERENCES Users(user_id)
		ON DELETE RESTRICT,
	CHECK (amount >= 0),
    CHECK (debtor_user_id != creditor_user_id),
    UNIQUE KEY unique_debt (group_id, debtor_user_id, creditor_user_id),
    INDEX idx_debtor (debtor_user_id),
    INDEX idx_creditor (creditor_user_id),
    INDEX idx_group_debt (group_id)
);
-- Table 6 (Settlements)
-- Tracks who has paid their debts and transactions between users
CREATE TABLE Settlements (
	settlement_id INT PRIMARY KEY AUTO_INCREMENT, 
    group_id INT NOT NULL,
    payer_user_id INT NOT NULL,
    recipient_user_id INT NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    settlement_date DATE NOT NULL,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    FOREIGN KEY (group_id) REFERENCES `Groups`(group_id)
		ON DELETE CASCADE,
    FOREIGN KEY (payer_user_id) REFERENCES Users(user_id)
		ON DELETE RESTRICT,
	FOREIGN KEY (recipient_user_id) REFERENCES Users(user_id)
		ON DELETE RESTRICT,
	CHECK (amount > 0),
    CHECK (payer_user_id != recipient_user_id),
    INDEX idx_group_settlement (group_id),
    INDEX idx_payer (payer_user_id),
    INDEX idx_recipient (recipient_user_id),
    INDEX idx_settlement_date (settlement_date)
);

-- Table 7 (Optimized Settlements) 
-- Stores the minimum transactions needed to settle all debts
-- This is the result of our settlement optimization algorithm
CREATE TABLE OptimizedSettlements (
    opt_settlement_id INT PRIMARY KEY,
    group_id INT NOT NULL,
    payer_user_id INT NOT NULL,
    recipient_user_id INT NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (group_id) REFERENCES `Groups`(group_id)
        ON DELETE CASCADE,
    FOREIGN KEY (payer_user_id) REFERENCES Users(user_id)
        ON DELETE RESTRICT,
    FOREIGN KEY (recipient_user_id) REFERENCES Users(user_id)
        ON DELETE RESTRICT,
    CHECK (amount > 0),
    CHECK (payer_user_id != recipient_user_id),
    INDEX idx_group_opt (group_id),
    INDEX idx_payer_opt (payer_user_id),
    INDEX idx_recipient_opt (recipient_user_id)
);