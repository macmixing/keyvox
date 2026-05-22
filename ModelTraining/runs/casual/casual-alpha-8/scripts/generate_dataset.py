#!/usr/bin/env python3
import json
import random
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODEL_TRAINING_ROOT = ROOT.parents[2]
DATA_DIR = MODEL_TRAINING_ROOT / "datasets" / "casual" / "casual-alpha-8-continuation-address-time-guards"
REPORT_DIR = ROOT / "reports"
SYSTEM_PROMPT = (
    MODEL_TRAINING_ROOT / "prompts" / "casual" / "casual_training_system.txt"
).read_text(encoding="utf-8").strip()


@dataclass(frozen=True)
class Example:
    category: str
    user: str
    assistant: str


def record(example: Example) -> dict:
    return {
        "category": example.category,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": example.user},
            {"role": "assistant", "content": example.assistant},
        ],
    }


def add(examples: list[Example], seen: set[str], category: str, user: str, assistant: str) -> None:
    if user in seen:
        return
    seen.add(user)
    examples.append(Example(category, user, assistant))


YEARS_2010S = [
    ("twenty ten", "2010"),
    ("twenty eleven", "2011"),
    ("twenty twelve", "2012"),
    ("twenty thirteen", "2013"),
    ("twenty fourteen", "2014"),
    ("twenty fifteen", "2015"),
    ("twenty sixteen", "2016"),
    ("twenty seventeen", "2017"),
    ("twenty eighteen", "2018"),
    ("twenty nineteen", "2019"),
]

YEARS_2020S = [
    ("twenty twenty", "2020"),
    ("twenty twenty one", "2021"),
    ("twenty twenty two", "2022"),
    ("twenty twenty three", "2023"),
    ("twenty twenty four", "2024"),
    ("twenty twenty five", "2025"),
    ("twenty twenty six", "2026"),
    ("twenty twenty seven", "2027"),
    ("twenty twenty eight", "2028"),
    ("twenty twenty nine", "2029"),
]

QUANTITIES = [
    ("twenty two", "22"),
    ("twenty five", "25"),
    ("twenty seven", "27"),
    ("twenty eight", "28"),
]

MONEY_DAY_AMOUNTS = [
    ("fifty", "$50"),
    ("one hundred", "$100"),
    ("a hundred", "$100"),
    ("forty-three", "$43"),
    ("forty three", "$43"),
    ("one hundred eighty", "$180"),
]

DAY_COUNTS = [
    ("three", "3"),
    ("seven", "7"),
]

STAR_RATING_COUNTS = [
    ("twelve", "12"),
]

PRICE_RATIO_PAIRS = [
    ("ten", "10", "one dollar", "$1"),
    ("two", "2", "one dollar", "$1"),
    ("four", "4", "one dollar", "$1"),
    ("five", "5", "one dollar", "$1"),
]

MONEY_MULTIPLIER_PAIRS = [
    ("fifty dollars", "$50"),
    ("fifty seven dollars", "$57"),
]

MULTIPLIER_COUNTS = [
    ("three", "3"),
]

SYMBOL_MULTIPLIER_PAIRS = [
    ("3", "50 dollars", "$50"),
    ("3", "57 dollars", "$57"),
]

NEGATED_MONEY_PAIRS = [
    ("five dollars", "$5", "three dollars", "$3"),
    ("three dollars", "$3", "five dollars", "$5"),
    ("twenty dollars", "$20", "five dollars", "$5"),
    ("twenty-five dollars", "$25", "twenty dollars", "$20"),
    ("twenty five dollars", "$25", "twenty dollars", "$20"),
    ("fifty dollars", "$50", "three dollars", "$3"),
]

MONEY_TIME_PAIRS = [
    ("twenty dollars", "$20", "three thirty", "3:30"),
    ("twenty-five dollars", "$25", "three thirty", "3:30"),
    ("twenty five dollars", "$25", "three thirty", "3:30"),
    ("thirty-five dollars", "$35", "five thirty", "5:30"),
    ("thirty five dollars", "$35", "five thirty", "5:30"),
    ("twenty two dollars", "$22", "four forty five", "4:45"),
    ("twenty-seven dollars", "$27", "eleven fifteen", "11:15"),
    ("twenty seven dollars", "$27", "eleven fifteen", "11:15"),
]

MONEY_TIME_CONTRAST_PAIRS = [
    ("twenty-five dollars", "$25", "three thirty", "3:30"),
    ("twenty five dollars", "$25", "three thirty", "3:30"),
    ("thirty-five dollars", "$35", "five thirty", "5:30"),
    ("thirty five dollars", "$35", "five thirty", "5:30"),
    ("forty dollars", "$40", "six fifteen", "6:15"),
    ("forty-two dollars", "$42", "seven forty five", "7:45"),
    ("forty-five dollars", "$45", "seven forty five", "7:45"),
    ("forty six dollars", "$46", "seven forty five", "7:45"),
    ("fifty dollars", "$50", "eight thirty", "8:30"),
]

SPOKEN_TIME_GUARDS = [
    ("six fifty five", "6:55"),
    ("seven twenty five", "7:25"),
    ("seven forty five", "7:45"),
    ("nine forty", "9:40"),
    ("eleven thirty five", "11:35"),
    ("twelve fifty", "12:50"),
]

ADDRESS_PAIRS = [
    ("655", "East", "Clifford", "Drive"),
    ("652", "North", "Washington", "Street"),
    ("852", "West", "General", "Street"),
    ("734", "South", "Maple", "Avenue"),
    ("945", "East", "Benton", "Road"),
    ("415", "North", "Cedar", "Lane"),
    ("530", "West", "Hudson", "Court"),
    ("930", "South", "Franklin", "Boulevard"),
    ("845", "East", "Mercer", "Way"),
    ("725", "North", "Pine", "Place"),
    ("615", "West", "Adams", "Drive"),
    ("750", "South", "Lincoln", "Street"),
]

ADDRESS_COMMA_PAIRS = [
    ("1,152", "1152", "North", "Washington", "Street"),
    ("1,155", "1155", "East", "Clifford", "Drive"),
    ("1,034", "1034", "West", "General", "Street"),
    ("1,230", "1230", "South", "Maple", "Avenue"),
    ("1,015", "1015", "North", "Cedar", "Lane"),
    ("1,245", "1245", "East", "Benton", "Road"),
    ("1,530", "1530", "West", "Hudson", "Court"),
    ("1,925", "1925", "South", "Franklin", "Boulevard"),
]

SPOKEN_ADDRESS_NUMBERS = {
    "655": ("six fifty five", "six five five"),
    "652": ("six fifty two", "six five two"),
    "852": ("eight fifty two", "eight five two"),
    "734": ("seven thirty four", "seven three four"),
    "945": ("nine forty five", "nine four five"),
    "415": ("four fifteen", "four one five"),
    "530": ("five thirty", "five three zero"),
    "930": ("nine thirty", "nine three zero"),
    "845": ("eight forty five", "eight four five"),
    "725": ("seven twenty five", "seven two five"),
    "615": ("six fifteen", "six one five"),
    "750": ("seven fifty", "seven five zero"),
}

SPOKEN_FOUR_DIGIT_ADDRESS_NUMBERS = {
    "1152": ("eleven fifty two", "one one five two"),
    "1155": ("eleven fifty five", "one one five five"),
    "1034": ("ten thirty four", "one zero three four"),
    "1230": ("twelve thirty", "one two three zero"),
    "1015": ("ten fifteen", "one zero one five"),
    "1245": ("twelve forty five", "one two four five"),
    "1530": ("fifteen thirty", "one five three zero"),
    "1925": ("nineteen twenty five", "one nine two five"),
}


def build_examples() -> list[Example]:
    examples: list[Example] = []
    seen: set[str] = set()

    for spoken, digits in YEARS_2010S:
        add(
            examples,
            seen,
            "spoken_year_2010s",
            f"I can't believe we haven't done that since what, {spoken}?",
            f"I can't believe we haven't done that since what, {digits}?",
        )
        add(
            examples,
            seen,
            "spoken_year_2010s",
            f"I'm pretty sure that movie came out in {spoken}. What do you think?",
            f"I'm pretty sure that movie came out in {digits}. What do you think?",
        )

    for spoken, digits in YEARS_2020S:
        add(
            examples,
            seen,
            "spoken_year_2020s",
            f"The renewal is {spoken} and the total is five hundred dollars.",
            f"The renewal is {digits} and the total is $500.",
        )

    mixed_pairs = [
        ("twenty twelve", "2012", "twenty eighteen", "2018"),
        ("twenty thirteen", "2013", "twenty nineteen", "2019"),
        ("twenty fifteen", "2015", "twenty twenty four", "2024"),
        ("twenty sixteen", "2016", "twenty twenty eight", "2028"),
    ]
    for first_spoken, first_digits, second_spoken, second_digits in mixed_pairs:
        add(
            examples,
            seen,
            "spoken_year_mixed",
            f"It feels like we've been doing this since {first_spoken}, but it's only {second_spoken}.",
            f"It feels like we've been doing this since {first_digits}, but it's only {second_digits}.",
        )

    for spoken, digits in QUANTITIES:
        add(
            examples,
            seen,
            "quantity_guard",
            f"The team closed {spoken} tickets, and this should stay casual.",
            f"The team closed {digits} tickets, and this should stay casual.",
        )

    for amount_spoken, amount_digits in MONEY_DAY_AMOUNTS:
        for day_spoken, day_digits in DAY_COUNTS:
            add(
                examples,
                seen,
                "money_day_boundary",
                f"I would have spent {amount_spoken} dollars {day_spoken} days ago.",
                f"I would have spent {amount_digits} {day_digits} days ago.",
            )
            add(
                examples,
                seen,
                "money_day_boundary",
                f"It probably would have cost {amount_spoken} dollars {day_spoken} days ago.",
                f"It probably would have cost {amount_digits} {day_digits} days ago.",
            )

    for count_spoken, count_digits in STAR_RATING_COUNTS:
        add(
            examples,
            seen,
            "star_rating_boundary",
            f"I have like {count_spoken} five star ratings right now.",
            f"I have like {count_digits} 5-star ratings right now.",
        )

    for count_spoken, count_digits, price_phrase, price_digits in PRICE_RATIO_PAIRS:
        add(
            examples,
            seen,
            "price_ratio_boundary",
            f"I ended up getting {count_spoken} for {price_phrase}.",
            f"I ended up getting {count_digits} for {price_digits}.",
        )
        add(
            examples,
            seen,
            "price_ratio_boundary",
            f"Yeah, I got {count_spoken} for {price_phrase}.",
            f"Yeah, I got {count_digits} for {price_digits}.",
        )
        add(
            examples,
            seen,
            "price_ratio_boundary",
            f"That deal was {count_spoken} for {price_phrase}.",
            f"That deal was {count_digits} for {price_digits}.",
        )

    for money_spoken, money_digits in MONEY_MULTIPLIER_PAIRS:
        for count_spoken, count_digits in MULTIPLIER_COUNTS:
            add(
                examples,
                seen,
                "math_money_boundary",
                f"Yeah, that was what? {money_spoken.capitalize()} multiplied by {count_spoken}?",
                f"Yeah, that was what? {money_digits} multiplied by {count_digits}?",
            )
            add(
                examples,
                seen,
                "math_money_boundary",
                f"Yeah, that was {money_spoken} multiplied by {count_spoken}.",
                f"Yeah, that was {money_digits} multiplied by {count_digits}.",
            )

    for left_digits, right_spoken, right_digits in SYMBOL_MULTIPLIER_PAIRS:
        add(
            examples,
            seen,
            "math_money_boundary",
            f"Yeah, that was {left_digits} * {right_spoken}.",
            f"Yeah, that was {left_digits} * {right_digits}.",
        )
        add(
            examples,
            seen,
            "math_money_boundary",
            f"What yeah, that was {left_digits} * {right_spoken}.",
            f"What yeah, that was {left_digits} * {right_digits}.",
        )

    money_boundary_pairs = [
        (
            "I have like twelve five star ratings right now.",
            "I have like 12 5-star ratings right now.",
        ),
        (
            "I would have spent fifty dollars seven days ago.",
            "I would have spent $50 7 days ago.",
        ),
        (
            "I would have spent one hundred dollars seven days ago.",
            "I would have spent $100 7 days ago.",
        ),
        (
            "I would have spent a hundred dollars seven days ago.",
            "I would have spent $100 7 days ago.",
        ),
        (
            "Yeah, I would have spent one hundred dollars seven days ago.",
            "Yeah, I would have spent $100 7 days ago.",
        ),
        (
            "It would have been one hundred dollars seven days ago.",
            "It would have been $100 7 days ago.",
        ),
        (
            "I would have spent forty-three dollars seven days ago.",
            "I would have spent $43 7 days ago.",
        ),
        (
            "I ended up getting ten for one dollar.",
            "I ended up getting 10 for $1.",
        ),
        (
            "I got ten for one dollar.",
            "I got 10 for $1.",
        ),
        (
            "Yeah, I ended up getting ten for one dollar.",
            "Yeah, I ended up getting 10 for $1.",
        ),
        (
            "It probably would have cost fifty dollars three days ago.",
            "It probably would have cost $50 3 days ago.",
        ),
        (
            "Yeah, that was what? Fifty dollars multiplied by three?",
            "Yeah, that was what? $50 multiplied by 3?",
        ),
        (
            "Yeah, that was 3 * 50 dollars.",
            "Yeah, that was 3 * $50.",
        ),
        (
            "What yeah, that was 3 * 57 dollars.",
            "What yeah, that was 3 * $57.",
        ),
        (
            "Move the call to 11:30 and send the one hundred eighty dollar invoice.",
            "Move the call to 11:30 and send the $180 invoice.",
        ),
        (
            "Send the one hundred eighty dollar invoice.",
            "Send the $180 invoice.",
        ),
        (
            "Yeah, send the one hundred eighty dollar invoice.",
            "Yeah, send the $180 invoice.",
        ),
    ]
    for user, assistant in money_boundary_pairs:
        add(examples, seen, "money_boundary_regression", user, assistant)

    for first_spoken, first_digits, second_spoken, second_digits in NEGATED_MONEY_PAIRS:
        add(
            examples,
            seen,
            "money_negation_boundary",
            f"Tell John the concert ain't {first_spoken}, but it'll be {second_spoken}.",
            f"Tell John the concert ain't {first_digits}, but it'll be {second_digits}.",
        )
        add(
            examples,
            seen,
            "money_negation_boundary",
            f"Tell John the concert is {first_spoken}, not {second_spoken}.",
            f"Tell John the concert is {first_digits}, not {second_digits}.",
        )
        add(
            examples,
            seen,
            "money_negation_boundary",
            f"I'm pretty sure that's like {first_spoken}, not {second_spoken}.",
            f"I'm pretty sure that's like {first_digits}, not {second_digits}.",
        )
        add(
            examples,
            seen,
            "money_negation_boundary",
            f"The cover is {first_spoken} instead of {second_spoken}.",
            f"The cover is {first_digits} instead of {second_digits}.",
        )

    for money_spoken, money_digits, time_spoken, time_digits in MONEY_TIME_PAIRS:
        add(
            examples,
            seen,
            "money_time_boundary",
            f"Um I'm pretty sure that's like {money_spoken} and starts at {time_spoken}.",
            f"I'm pretty sure that's like {money_digits} and starts at {time_digits}.",
        )
        add(
            examples,
            seen,
            "money_time_boundary",
            f"I'm pretty sure that's {money_spoken} and the show starts at {time_spoken}.",
            f"I'm pretty sure that's {money_digits} and the show starts at {time_digits}.",
        )
        add(
            examples,
            seen,
            "money_time_boundary",
            f"Yeah, tickets are {money_spoken} and doors open at {time_spoken}.",
            f"Yeah, tickets are {money_digits} and doors open at {time_digits}.",
        )

    for money_spoken, money_digits, time_spoken, time_digits in MONEY_TIME_CONTRAST_PAIRS:
        add(
            examples,
            seen,
            "money_time_contrast_boundary",
            f"I'm pretty sure that ain't {money_spoken}, but I definitely know it starts at {time_spoken}.",
            f"I'm pretty sure that ain't {money_digits}, but I definitely know it starts at {time_digits}.",
        )
        add(
            examples,
            seen,
            "money_time_contrast_boundary",
            f"I'm pretty sure that isn't {money_spoken}, but I definitely know it starts at {time_spoken}.",
            f"I'm pretty sure that isn't {money_digits}, but I definitely know it starts at {time_digits}.",
        )
        add(
            examples,
            seen,
            "money_time_contrast_boundary",
            f"I don't think it's {money_spoken}, but I know it starts at {time_spoken}.",
            f"I don't think it's {money_digits}, but I know it starts at {time_digits}.",
        )
        add(
            examples,
            seen,
            "money_time_contrast_boundary",
            f"The price is not {money_spoken}, and the start time is {time_spoken}.",
            f"The price is not {money_digits}, and the start time is {time_digits}.",
        )
        add(
            examples,
            seen,
            "money_time_contrast_boundary",
            f"The ticket price should be {money_spoken}, and the event starts at {time_spoken}.",
            f"The ticket price should be {money_digits}, and the event starts at {time_digits}.",
        )
        add(
            examples,
            seen,
            "money_time_contrast_boundary",
            f"Please confirm {money_spoken} for the ticket and {time_spoken} for the start.",
            f"Please confirm {money_digits} for the ticket and {time_digits} for the start.",
        )

    for time_spoken, time_digits in SPOKEN_TIME_GUARDS:
        add(
            examples,
            seen,
            "spoken_time_guard",
            f"Remind me to check the build at {time_spoken}.",
            f"Remind me to check the build at {time_digits}.",
        )
        add(
            examples,
            seen,
            "spoken_time_guard",
            f"Move the follow up to {time_spoken} and keep it casual.",
            f"Move the follow up to {time_digits} and keep it casual.",
        )
        add(
            examples,
            seen,
            "spoken_time_guard",
            f"Sarah and me was going to meet at {time_spoken}.",
            f"Sarah and me was going to meet at {time_digits}.",
        )
        add(
            examples,
            seen,
            "spoken_time_guard",
            f"I ain't showing up before {time_spoken}.",
            f"I ain't showing up before {time_digits}.",
        )
        add(
            examples,
            seen,
            "spoken_time_guard",
            f"This shit needs to be done by {time_spoken}.",
            f"This shit needs to be done by {time_digits}.",
        )
        add(
            examples,
            seen,
            "spoken_time_guard",
            f"The start time is {time_spoken}.",
            f"The start time is {time_digits}.",
        )
        add(
            examples,
            seen,
            "spoken_time_guard",
            f"The address is 655 East Clifford Drive, and the time is {time_spoken}.",
            f"The address is 655 East Clifford Drive, and the time is {time_digits}.",
        )

    for number, direction, name, suffix in ADDRESS_PAIRS:
        address = f"{number} {direction} {name} {suffix}"
        spoken_addresses = [
            f"{spoken_number} {direction} {name} {suffix}"
            for spoken_number in SPOKEN_ADDRESS_NUMBERS[number]
        ]
        add(
            examples,
            seen,
            "address_time_guard",
            f"Meet me at {address}.",
            f"Meet me at {address}.",
        )
        add(
            examples,
            seen,
            "address_time_guard",
            f"Send it to {address}.",
            f"Send it to {address}.",
        )
        add(
            examples,
            seen,
            "address_time_guard",
            f"I'll be waiting at {address}.",
            f"I'll be waiting at {address}.",
        )
        add(
            examples,
            seen,
            "address_time_guard",
            f"The pickup is at {address}.",
            f"The pickup is at {address}.",
        )
        add(
            examples,
            seen,
            "address_time_guard",
            f"Drop the package at {address}.",
            f"Drop the package at {address}.",
        )
        add(
            examples,
            seen,
            "address_with_time_guard",
            f"Meet me at {address} at three thirty.",
            f"Meet me at {address} at 3:30.",
        )
        add(
            examples,
            seen,
            "address_with_time_guard",
            f"The appointment is at three thirty at {address}.",
            f"The appointment is at 3:30 at {address}.",
        )
        for spoken_address in spoken_addresses:
            add(
                examples,
                seen,
                "address_spoken_guard",
                f"Meet me at {spoken_address}.",
                f"Meet me at {address}.",
            )
            add(
                examples,
                seen,
                "address_spoken_guard",
                f"Send it to {spoken_address}.",
                f"Send it to {address}.",
            )
            add(
                examples,
                seen,
                "address_spoken_guard",
                f"The pickup is at {spoken_address}.",
                f"The pickup is at {address}.",
            )
            add(
                examples,
                seen,
                "address_spoken_with_time_guard",
                f"Meet me at {spoken_address} at three thirty.",
                f"Meet me at {address} at 3:30.",
            )
            add(
                examples,
                seen,
                "address_spoken_with_time_guard",
                f"The appointment is at three thirty at {spoken_address}.",
                f"The appointment is at 3:30 at {address}.",
            )

    for comma_number, number, direction, name, suffix in ADDRESS_COMMA_PAIRS:
        address = f"{number} {direction} {name} {suffix}"
        comma_address = f"{comma_number} {direction} {name} {suffix}"
        spoken_addresses = [
            f"{spoken_number} {direction} {name} {suffix}"
            for spoken_number in SPOKEN_FOUR_DIGIT_ADDRESS_NUMBERS[number]
        ]
        add(
            examples,
            seen,
            "address_comma_guard",
            f"Meet me at {comma_address}.",
            f"Meet me at {address}.",
        )
        add(
            examples,
            seen,
            "address_comma_guard",
            f"Send it to {comma_address}.",
            f"Send it to {address}.",
        )
        add(
            examples,
            seen,
            "address_comma_guard",
            f"Drop the package at {comma_address}.",
            f"Drop the package at {address}.",
        )
        add(
            examples,
            seen,
            "address_comma_with_time_guard",
            f"Meet me at {comma_address} at three thirty.",
            f"Meet me at {address} at 3:30.",
        )
        for spoken_address in spoken_addresses:
            add(
                examples,
                seen,
                "address_spoken_four_digit_guard",
                f"Meet me at {spoken_address}.",
                f"Meet me at {address}.",
            )
            add(
                examples,
                seen,
                "address_spoken_four_digit_guard",
                f"Send it to {spoken_address}.",
                f"Send it to {address}.",
            )
            add(
                examples,
                seen,
                "address_spoken_four_digit_guard",
                f"Drop the package at {spoken_address}.",
                f"Drop the package at {address}.",
            )
            add(
                examples,
                seen,
                "address_spoken_four_digit_guard",
                f"The address is {spoken_address}.",
                f"The address is {address}.",
            )
            add(
                examples,
                seen,
                "address_spoken_four_digit_with_time_guard",
                f"Meet me at {spoken_address} at three thirty.",
                f"Meet me at {address} at 3:30.",
            )
            add(
                examples,
                seen,
                "address_spoken_four_digit_with_time_guard",
                f"The appointment is at three thirty at {spoken_address}.",
                f"The appointment is at 3:30 at {address}.",
            )

    targeted_address_regressions = [
        (
            "Meet me at 1,152 North Washington Street.",
            "Meet me at 1152 North Washington Street.",
        ),
        (
            "Please meet me at 1,152 North Washington Street.",
            "Please meet me at 1152 North Washington Street.",
        ),
        (
            "Send it to 1,034 West General Street.",
            "Send it to 1034 West General Street.",
        ),
        (
            "The address is 1,152 North Washington Street.",
            "The address is 1152 North Washington Street.",
        ),
        (
            "Drop it at 1,152 North Washington Street.",
            "Drop it at 1152 North Washington Street.",
        ),
        (
            "Send the package to 1,152 North Washington Street.",
            "Send the package to 1152 North Washington Street.",
        ),
        (
            "The pickup address is 1,152 North Washington Street.",
            "The pickup address is 1152 North Washington Street.",
        ),
        (
            "The delivery goes to 1,152 North Washington Street.",
            "The delivery goes to 1152 North Washington Street.",
        ),
        (
            "I'll meet you at 1,152 North Washington Street.",
            "I'll meet you at 1152 North Washington Street.",
        ),
        (
            "Please send that over to 1,152 North Washington Street.",
            "Please send that over to 1152 North Washington Street.",
        ),
        (
            "Go to 1,152 North Washington Street.",
            "Go to 1152 North Washington Street.",
        ),
        (
            "Put the stop at 1,152 North Washington Street.",
            "Put the stop at 1152 North Washington Street.",
        ),
        (
            "Meet me at ten thirty four West General Street.",
            "Meet me at 1034 West General Street.",
        ),
        (
            "Meet me at eleven fifty two North Washington Street.",
            "Meet me at 1152 North Washington Street.",
        ),
        (
            "The address is ten thirty four West General Street, and the meeting is at three thirty.",
            "The address is 1034 West General Street, and the meeting is at 3:30.",
        ),
        (
            "The address is eleven fifty two North Washington Street, and the meeting is at three thirty.",
            "The address is 1152 North Washington Street, and the meeting is at 3:30.",
        ),
        (
            "Meet me at six five five East Clifford Drive.",
            "Meet me at 655 East Clifford Drive.",
        ),
        (
            "Please meet me at six five five East Clifford Drive.",
            "Please meet me at 655 East Clifford Drive.",
        ),
        (
            "Meet me at six fifty two North Washington Street.",
            "Meet me at 652 North Washington Street.",
        ),
        (
            "Please meet me at six fifty two North Washington Street.",
            "Please meet me at 652 North Washington Street.",
        ),
        (
            "Meet me at eight fifty two West General Street.",
            "Meet me at 852 West General Street.",
        ),
        (
            "Please meet me at eight fifty two West General Street.",
            "Please meet me at 852 West General Street.",
        ),
    ]
    for user, assistant in targeted_address_regressions:
        add(examples, seen, "address_regression_guard", user, assistant)

    live_spoken_address_regressions = [
        ("655", "six fifty five", "East", "Clifford", "Drive"),
        ("655", "six five five", "East", "Clifford", "Drive"),
        ("652", "six fifty two", "North", "Washington", "Street"),
        ("652", "six five two", "North", "Washington", "Street"),
        ("852", "eight fifty two", "West", "General", "Street"),
        ("852", "eight five two", "West", "General", "Street"),
    ]
    live_spoken_address_templates = [
        ("Meet me at {spoken_address}.", "Meet me at {address}."),
        ("Please meet me at {spoken_address}.", "Please meet me at {address}."),
        ("I'll meet you at {spoken_address}.", "I'll meet you at {address}."),
        ("Can you meet me at {spoken_address}?", "Can you meet me at {address}?"),
        ("Come meet me at {spoken_address}.", "Come meet me at {address}."),
        ("Send it to {spoken_address}.", "Send it to {address}."),
        ("Please send it to {spoken_address}.", "Please send it to {address}."),
        ("Drop it at {spoken_address}.", "Drop it at {address}."),
        ("Drop the package at {spoken_address}.", "Drop the package at {address}."),
        ("The address is {spoken_address}.", "The address is {address}."),
        ("The address should be {spoken_address}.", "The address should be {address}."),
        ("The pickup is at {spoken_address}.", "The pickup is at {address}."),
        ("The delivery goes to {spoken_address}.", "The delivery goes to {address}."),
        ("The stop is {spoken_address}.", "The stop is {address}."),
        ("Go to {spoken_address}.", "Go to {address}."),
        ("Please go to {spoken_address}.", "Please go to {address}."),
        (
            "Meet me at {spoken_address} at three thirty.",
            "Meet me at {address} at 3:30.",
        ),
        (
            "The appointment is at three thirty at {spoken_address}.",
            "The appointment is at 3:30 at {address}.",
        ),
    ]
    for number, spoken_number, direction, name, suffix in live_spoken_address_regressions:
        address = f"{number} {direction} {name} {suffix}"
        spoken_address = f"{spoken_number} {direction} {name} {suffix}"
        for user_template, assistant_template in live_spoken_address_templates:
            add(
                examples,
                seen,
                "address_live_regression_guard",
                user_template.format(spoken_address=spoken_address),
                assistant_template.format(address=address),
            )

    live_comma_address_templates = [
        ("Meet me at {comma_address}.", "Meet me at {address}."),
        ("Please meet me at {comma_address}.", "Please meet me at {address}."),
        ("I'll meet you at {comma_address}.", "I'll meet you at {address}."),
        ("Can you meet me at {comma_address}?", "Can you meet me at {address}?"),
        ("Come meet me at {comma_address}.", "Come meet me at {address}."),
        ("Send it to {comma_address}.", "Send it to {address}."),
        ("Please send it to {comma_address}.", "Please send it to {address}."),
        ("Drop it at {comma_address}.", "Drop it at {address}."),
        ("Drop the package at {comma_address}.", "Drop the package at {address}."),
        ("The address is {comma_address}.", "The address is {address}."),
        ("The address should be {comma_address}.", "The address should be {address}."),
        ("The pickup is at {comma_address}.", "The pickup is at {address}."),
        ("The delivery goes to {comma_address}.", "The delivery goes to {address}."),
        ("The stop is {comma_address}.", "The stop is {address}."),
        ("Go to {comma_address}.", "Go to {address}."),
        ("Please go to {comma_address}.", "Please go to {address}."),
        (
            "Meet me at {comma_address} at three thirty.",
            "Meet me at {address} at 3:30.",
        ),
        (
            "The appointment is at three thirty at {comma_address}.",
            "The appointment is at 3:30 at {address}.",
        ),
    ]
    for comma_number, number, direction, name, suffix in ADDRESS_COMMA_PAIRS:
        address = f"{number} {direction} {name} {suffix}"
        comma_address = f"{comma_number} {direction} {name} {suffix}"
        for user_template, assistant_template in live_comma_address_templates:
            add(
                examples,
                seen,
                "address_comma_live_regression_guard",
                user_template.format(comma_address=comma_address),
                assistant_template.format(address=address),
            )

    live_spoken_time_regressions = [
        ("four forty five", "4:45"),
        ("six fifty five", "6:55"),
        ("six fifty two", "6:52"),
        ("seven twenty five", "7:25"),
        ("seven forty five", "7:45"),
        ("eight fifty two", "8:52"),
        ("nine forty", "9:40"),
        ("eleven thirty five", "11:35"),
        ("twelve fifty", "12:50"),
    ]
    live_spoken_time_templates = [
        ("Meet me at {spoken_time}.", "Meet me at {time}."),
        ("Hey, can you meet me for lunch tomorrow at {spoken_time}?", "Hey, can you meet me for lunch tomorrow at {time}?"),
        ("The appointment is at {spoken_time}.", "The appointment is at {time}."),
        ("The follow up is at {spoken_time}.", "The follow up is at {time}."),
        ("The call starts at {spoken_time}.", "The call starts at {time}."),
        ("The start time is {spoken_time}.", "The start time is {time}."),
        ("Sarah and me was going to meet at {spoken_time}.", "Sarah and me was going to meet at {time}."),
        ("I ain't showing up before {spoken_time}.", "I ain't showing up before {time}."),
        ("This shit needs to be done by {spoken_time}.", "This shit needs to be done by {time}."),
    ]
    for spoken_time, time in live_spoken_time_regressions:
        for user_template, assistant_template in live_spoken_time_templates:
            add(
                examples,
                seen,
                "spoken_time_live_regression_guard",
                user_template.format(spoken_time=spoken_time),
                assistant_template.format(time=time),
            )

    money_time_live_regressions = [
        ("forty-two dollars", "$42", "seven forty five", "7:45"),
        ("forty six dollars", "$46", "seven forty five", "7:45"),
        ("fifty-two dollars", "$52", "seven forty five", "7:45"),
        ("forty-five dollars", "$45", "seven twenty five", "7:25"),
        ("forty-five dollars", "$45", "nine forty", "9:40"),
    ]
    money_time_live_templates = [
        ("The price is not {money_spoken}, and the start time is {time_spoken}.", "The price is not {money}, and the start time is {time}."),
        ("The price isn't {money_spoken}, and the start time is {time_spoken}.", "The price isn't {money}, and the start time is {time}."),
        ("The cost is not {money_spoken}, and it starts at {time_spoken}.", "The cost is not {money}, and it starts at {time}."),
        ("That should be {money_spoken}, and the start time is {time_spoken}.", "That should be {money}, and the start time is {time}."),
    ]
    for money_spoken, money, time_spoken, time in money_time_live_regressions:
        for user_template, assistant_template in money_time_live_templates:
            add(
                examples,
                seen,
                "money_time_live_regression_guard",
                user_template.format(money_spoken=money_spoken, time_spoken=time_spoken),
                assistant_template.format(money=money, time=time),
            )

    guard_pairs = [
        (
            "Um okay, like I tested the adapter for 20 minutes, and I ain't saying it's perfect.",
            "Okay, like I tested the adapter for 20 minutes, and I ain't saying it's perfect.",
        ),
        (
            "Sarah and me was trying a few weird cases.",
            "Sarah and me was trying a few weird cases.",
        ),
        (
            "What you be doing matters less than whether the words stay put.",
            "What you be doing matters less than whether the words stay put.",
        ),
        (
            "Why the fuck is this button still weird?",
            "Why the fuck is this button still weird?",
        ),
        (
            "Move the call to 11:30 and send the one hundred eighty dollar invoice.",
            "Move the call to 11:30 and send the $180 invoice.",
        ),
        (
            "I need groceries:\n\n1. Um apples\n2. Like bananas\n3. Uh grapes",
            "I need groceries:\n\n1. Apples\n2. Like bananas\n3. Grapes",
        ),
    ]
    for user, assistant in guard_pairs:
        add(examples, seen, "casual_voice_guard", user, assistant)

    random.Random(44).shuffle(examples)
    return examples


def write_split(path: Path, examples: list[Example]) -> None:
    with path.open("w", encoding="utf-8") as handle:
        for example in examples:
            handle.write(json.dumps(record(example), ensure_ascii=False) + "\n")


def main() -> int:
    examples = build_examples()
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_DIR.mkdir(parents=True, exist_ok=True)

    valid = [
        Example(
            "spoken_year_2010s",
            "I can't believe so much time has passed. I haven't seen you since like twenty twelve.",
            "I can't believe so much time has passed. I haven't seen you since like 2012.",
        ),
        Example(
            "spoken_year_2010s",
            "The audit started in twenty eighteen and wrapped up in twenty nineteen.",
            "The audit started in 2018 and wrapped up in 2019.",
        ),
        Example(
            "quantity_guard",
            "The team closed twenty two tickets and reopened twenty eight.",
            "The team closed 22 tickets and reopened 28.",
        ),
        Example(
            "casual_voice_guard",
            "I ain't changing the invoice from one hundred eighty dollars.",
            "I ain't changing the invoice from $180.",
        ),
        Example(
            "money_negation_boundary",
            "Tell John the concert is three dollars, not five dollars.",
            "Tell John the concert is $3, not $5.",
        ),
        Example(
            "money_time_boundary",
            "Um I'm pretty sure that's like twenty dollars and starts at three thirty.",
            "I'm pretty sure that's like $20 and starts at 3:30.",
        ),
        Example(
            "money_time_contrast_boundary",
            "I'm pretty sure that isn't forty dollars, but I definitely know it starts at six fifteen.",
            "I'm pretty sure that isn't $40, but I definitely know it starts at 6:15.",
        ),
        Example(
            "money_time_contrast_boundary",
            "The ticket price should be fifty dollars, and the event starts at eight thirty.",
            "The ticket price should be $50, and the event starts at 8:30.",
        ),
        Example(
            "address_time_guard",
            "Meet me at 655 East Clifford Drive.",
            "Meet me at 655 East Clifford Drive.",
        ),
        Example(
            "address_with_time_guard",
            "The appointment is at three thirty at 652 North Washington Street.",
            "The appointment is at 3:30 at 652 North Washington Street.",
        ),
        Example(
            "address_spoken_guard",
            "Meet me at six fifty five East Clifford Drive.",
            "Meet me at 655 East Clifford Drive.",
        ),
        Example(
            "address_spoken_with_time_guard",
            "The appointment is at three thirty at six five two North Washington Street.",
            "The appointment is at 3:30 at 652 North Washington Street.",
        ),
        Example(
            "address_comma_guard",
            "The drop is at 1,152 North Washington Street.",
            "The drop is at 1152 North Washington Street.",
        ),
        Example(
            "address_spoken_four_digit_guard",
            "Send it to eleven fifty two North Washington Street.",
            "Send it to 1152 North Washington Street.",
        ),
    ]
    test = [
        Example(
            "spoken_year_mixed",
            "It feels like we've been doing this since twenty twelve, but it's only twenty eighteen.",
            "It feels like we've been doing this since 2012, but it's only 2018.",
        ),
        Example(
            "spoken_year_2010s",
            "I can't believe we haven't done that since what, twenty twelve?",
            "I can't believe we haven't done that since what, 2012?",
        ),
        Example(
            "quantity_guard",
            "Please order twenty five labels and twenty nine envelopes.",
            "Please order 25 labels and 29 envelopes.",
        ),
        Example(
            "casual_voice_guard",
            "Sarah and me was checking the list at three thirty.",
            "Sarah and me was checking the list at 3:30.",
        ),
        Example(
            "money_negation_boundary",
            "Tell John the concert ain't five dollars, but it'll be three dollars.",
            "Tell John the concert ain't $5, but it'll be $3.",
        ),
        Example(
            "money_time_boundary",
            "Um I'm pretty sure that's like twenty-five dollars and starts at three thirty.",
            "I'm pretty sure that's like $25 and starts at 3:30.",
        ),
        Example(
            "money_time_contrast_boundary",
            "I'm pretty sure that ain't twenty-five dollars, but I definitely know it starts at three thirty.",
            "I'm pretty sure that ain't $25, but I definitely know it starts at 3:30.",
        ),
        Example(
            "money_time_contrast_boundary",
            "I'm pretty sure that ain't thirty-five dollars, but I definitely know it starts at five thirty.",
            "I'm pretty sure that ain't $35, but I definitely know it starts at 5:30.",
        ),
        Example(
            "money_time_contrast_boundary",
            "The price is not forty-five dollars, and the start time is seven forty five.",
            "The price is not $45, and the start time is 7:45.",
        ),
        Example(
            "address_time_guard",
            "Meet me at 652 North Washington Street.",
            "Meet me at 652 North Washington Street.",
        ),
        Example(
            "address_time_guard",
            "Meet me at 852 West General Street.",
            "Meet me at 852 West General Street.",
        ),
        Example(
            "address_time_guard",
            "Drop the package at 734 South Maple Avenue.",
            "Drop the package at 734 South Maple Avenue.",
        ),
        Example(
            "address_with_time_guard",
            "Meet me at 655 East Clifford Drive at three thirty.",
            "Meet me at 655 East Clifford Drive at 3:30.",
        ),
        Example(
            "address_spoken_guard",
            "Meet me at six five five East Clifford Drive.",
            "Meet me at 655 East Clifford Drive.",
        ),
        Example(
            "address_spoken_guard",
            "Drop the package at six fifty two North Washington Street.",
            "Drop the package at 652 North Washington Street.",
        ),
        Example(
            "address_spoken_guard",
            "Drop the package at eight fifty two West General Street.",
            "Drop the package at 852 West General Street.",
        ),
        Example(
            "address_spoken_guard",
            "Drop the package at seven three four South Maple Avenue.",
            "Drop the package at 734 South Maple Avenue.",
        ),
        Example(
            "address_spoken_with_time_guard",
            "Meet me at six fifty five East Clifford Drive at three thirty.",
            "Meet me at 655 East Clifford Drive at 3:30.",
        ),
        Example(
            "address_comma_guard",
            "Meet me at 1,155 East Clifford Drive.",
            "Meet me at 1155 East Clifford Drive.",
        ),
        Example(
            "address_comma_guard",
            "Drop the package at 1,034 West General Street.",
            "Drop the package at 1034 West General Street.",
        ),
        Example(
            "address_spoken_four_digit_guard",
            "Meet me at eleven fifty five East Clifford Drive.",
            "Meet me at 1155 East Clifford Drive.",
        ),
        Example(
            "address_spoken_four_digit_guard",
            "Send it to ten thirty four West General Street.",
            "Send it to 1034 West General Street.",
        ),
        Example(
            "address_spoken_four_digit_with_time_guard",
            "Meet me at eleven fifty two North Washington Street at three thirty.",
            "Meet me at 1152 North Washington Street at 3:30.",
        ),
    ]

    held_out = {example.user for example in valid + test}
    train = [example for example in examples if example.user not in held_out]

    write_split(DATA_DIR / "train.jsonl", train)
    write_split(DATA_DIR / "valid.jsonl", valid)
    write_split(DATA_DIR / "test.jsonl", test)

    manifest = {
        "version": "casual-alpha-8",
        "purpose": "continuation from casual-alpha-7 for numeric, comma-separated, and spoken address number guards so street addresses are not rewritten as times while nearby spoken times still format correctly",
        "train_count": len(train),
        "valid_count": len(valid),
        "test_count": len(test),
        "categories": Counter(example.category for example in train + valid + test),
    }
    with (REPORT_DIR / "dataset_manifest.json").open("w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2, sort_keys=True)
        handle.write("\n")

    print(f"wrote {len(train)} train, {len(valid)} valid, {len(test)} test examples to {DATA_DIR}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
