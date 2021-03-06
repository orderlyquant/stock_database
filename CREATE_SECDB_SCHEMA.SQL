.print "Creating SECDB schema objects..."

-- gics table - defines sector, industry group, industry and sub-industry classifications supplied by GICS
CREATE TABLE IF NOT EXISTS gics
(
    code INTEGER PRIMARY KEY,
    level TEXT NOT NULL,
    name TEXT NOT NULL 
);
CREATE UNIQUE INDEX IF NOT EXISTS gics_name
ON gics ( level, name );

-- security_table - defines securities uniquely with definitional data that may change through time
CREATE TABLE IF NOT EXISTS security
(
    uid INTEGER NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    symbol TEXT NOT NULL,
    name TEXT NOT NULL,
    sub_industry_code INTEGER,
    PRIMARY KEY(uid, start_date),
    FOREIGN KEY(sub_industry_code) REFERENCES gics(code)
);
CREATE UNIQUE INDEX IF NOT EXISTS security_symbol
ON security ( symbol, start_date );

-- security_price table - contains specific price information as of the effective_date for securities
CREATE TABLE IF NOT EXISTS security_price
(
    uid INTEGER NOT NULL,
    effective_date DATE NOT NULL,
    closing_price DOUBLE,
    volume DOUBLE, 
    price_return DOUBLE,
    total_return DOUBLE,
    price_return_factor DOUBLE,
    total_return_factor DOUBLE,
    dividend DOUBLE,
    split_factor DOUBLE,
    PRIMARY KEY(uid, effective_date),
    FOREIGN KEY(uid) REFERENCES security(uid)
);
CREATE INDEX IF NOT EXISTS security_price_effective_date
ON security_price ( effective_date );
CREATE INDEX IF NOT EXISTS security_price_uid
ON security_price ( uid );

-- factor table - defines factors collected for securities
CREATE TABLE IF NOT EXISTS factor
(
    uid INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT
);

-- factor_data table - contains raw and scored factor data as of the effective_date for securities
CREATE TABLE IF NOT EXISTS factor_data
(
    factor_uid INTEGER NOT NULL,
    security_uid INTEGER NOT NULL,
    effective_date DATE NOT NULL,
    raw_value DOUBLE,
    score DOUBLE,
    rank INTEGER,
    PRIMARY KEY(factor_uid, security_uid, effective_date),
    FOREIGN KEY(factor_uid) REFERENCES factor(uid),
    FOREIGN KEY(security_uid) REFERENCES security(uid)
);

-- adjusted price view - enforces calculation of adjusted_price and adjusted_price_pret
CREATE VIEW adjusted_price
AS
SELECT  uid,
        effective_date,
        closing_price,
        volume,
        closing_price / total_return_factor AS adjusted_price,
        closing_price / price_return_factor AS adjusted_price_pret,
        volume * price_return_factor AS adjusted_volume,
        price_return,
        total_return
FROM    security_price;

.exit
