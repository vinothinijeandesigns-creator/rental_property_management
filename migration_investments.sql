-- 1. Create investments table
CREATE TABLE public.investments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type TEXT NOT NULL, -- 'FD', 'RD', 'Lending', 'Shares', 'Other'
    title TEXT NOT NULL, -- e.g. Bank Name, Borrower Name
    principal_amount NUMERIC NOT NULL,
    interest_rate NUMERIC NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE, -- Maturity date or End date
    status TEXT DEFAULT 'Active', -- 'Active', 'Closed'
    details JSONB, -- Stores specific fields (e.g. interest_type, monthly_payment_date, borrower_phone, tenure)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Create investment_transactions table
CREATE TABLE public.investment_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    investment_id UUID REFERENCES public.investments(id) ON DELETE CASCADE,
    transaction_type TEXT NOT NULL, -- 'Deposit' (RD), 'Interest' (Lending), 'Settlement'
    amount NUMERIC NOT NULL,
    transaction_date DATE NOT NULL,
    related_month TEXT, -- e.g. "Aug 2026"
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
