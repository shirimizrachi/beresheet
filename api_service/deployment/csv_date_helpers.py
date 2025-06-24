"""
CSV Date Helper Functions
Common date processing functions for CSV data loaders
"""

import re
from datetime import datetime, timedelta
from typing import Optional
import logging

logger = logging.getLogger(__name__)

def process_csv_date_functions(value: str) -> Optional[str]:
    """
    Process CSV date function strings and convert them to ISO datetime strings
    
    Supported functions:
    - datenow() -> current datetime
    - dateadd(X,days) -> current date + X days  
    - dateadd(X,months) -> current date + X months
    - dateadd(X,years) -> current date + X years
    
    Args:
        value: String value from CSV that may contain date functions
        
    Returns:
        ISO formatted datetime string or None if not a date function
    """
    if not value or not isinstance(value, str):
        return None
    
    value = value.strip()
    
    # Handle datenow() function
    if value.lower() == 'datenow()':
        return datetime.now().isoformat()
    
    # Handle dateadd functions
    dateadd_pattern = r'dateadd\((\d+),\s*(days?|months?|years?)\)'
    match = re.match(dateadd_pattern, value.lower())
    
    if match:
        amount = int(match.group(1))
        unit = match.group(2).lower()
        
        base_date = datetime.now()
        
        if unit.startswith('day'):
            result_date = base_date + timedelta(days=amount)
        elif unit.startswith('month'):
            # Approximate months as 30 days
            result_date = base_date + timedelta(days=amount * 30)
        elif unit.startswith('year'):
            # Approximate years as 365 days
            result_date = base_date + timedelta(days=amount * 365)
        else:
            logger.warning(f"Unknown date unit: {unit}")
            return None
            
        return result_date.isoformat()
    
    # If it's not a date function, return None
    return None

def process_csv_field(field_value: str, field_name: str = "") -> str:
    """
    Process a CSV field value, converting date functions if present
    
    Args:
        field_value: The raw field value from CSV
        field_name: Optional field name for logging
        
    Returns:
        Processed field value (either converted date or original value)
    """
    if not field_value:
        return field_value
    
    # Try to process as date function
    processed_date = process_csv_date_functions(field_value)
    
    if processed_date is not None:
        logger.debug(f"Converted date function '{field_value}' to '{processed_date}' for field '{field_name}'")
        return processed_date
    
    # Return original value if not a date function
    return field_value

def process_csv_row(row_dict: dict) -> dict:
    """
    Process an entire CSV row dictionary, converting any date functions found
    
    Args:
        row_dict: Dictionary representing a CSV row
        
    Returns:
        Dictionary with date functions converted to actual dates
    """
    processed_row = {}
    
    for key, value in row_dict.items():
        processed_row[key] = process_csv_field(value, key)
    
    return processed_row

# Predefined date function examples for documentation:
DATE_FUNCTION_EXAMPLES = {
    'datenow()': 'Current date and time',
    'dateadd(1,day)': 'Current date + 1 day',
    'dateadd(7,days)': 'Current date + 7 days', 
    'dateadd(1,month)': 'Current date + 1 month',
    'dateadd(3,months)': 'Current date + 3 months',
    'dateadd(1,year)': 'Current date + 1 year'
}