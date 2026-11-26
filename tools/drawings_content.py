"""Transcribed index of the curriculum topic drawings.

``التربية_الفنية_14_موضوعا_صورة_واحدة_لكل_موضوع.docx`` provides the first
fourteen topic drawings (``drawing-01`` .. ``drawing-14``), and
``tools/extra_drawings/`` provides six supplemental Grade 3 topic drawings
(``drawing-15`` .. ``drawing-20``) so every middle-school grade has balanced
visual models across drawing, perspective, figure proportion, still life,
ornament, calligraphy, and poster composition.
"""

from __future__ import annotations

from typing import Dict, List

DRAWINGS_TITLE = "موضوعات مصوّرة"
DRAWINGS_SUBTITLE = "نماذج مرسومة لموضوعات الرسم والتصميم والزخرفة"
DRAWINGS_INTRO = (
    "عشرون موضوعاً عملياً في الرسم والمنظور والنسب والطبيعة الصامتة والتصميم "
    "والزخرفة والخط عبر الصفوف الثلاثة. تظهر صورة كل موضوع في بداية الموضوع "
    "المرتبط به داخل الوحدة، وتُجمع كلها هنا وفي معرض الرسوم التوضيحية."
)

#: The fourteen pages of ``التربية_الفنية_14_موضوعا_صورة_واحدة_لكل_موضوع.docx``,
#: in exact document order.
DRAWINGS: List[Dict[str, str]] = [
    {"title": "تصميم غلاف كتاب", "unitId": "g1-u2", "topicId": "t2"},
    {"title": "تصميم بطاقة معايدة", "unitId": "g1-u2", "topicId": "t2"},
    {"title": "تصميم بطاقة دعوة", "unitId": "g1-u2", "topicId": "t2"},
    {"title": "تصميم إعلان", "unitId": "g1-u2", "topicId": "t1"},
    {"title": "تصميم زخارف بالحروف العربية", "unitId": "g2-u2", "topicId": "t1"},
    {"title": "رسم أشكال هندسية منتظمة", "unitId": "g2-u2", "topicId": "t2"},
    {"title": "تكوين زخرفي يعتمد على التكرار", "unitId": "g1-u2", "topicId": "t4"},
    {"title": "رسم وحدات زخرفية طبيعية أو هندسية", "unitId": "g1-u2", "topicId": "t3"},
    {"title": "تصميم زخرفة تعتمد على التماثل والتناظر", "unitId": "g2-u2", "topicId": "t3"},
    {"title": "رسم تكوين زخرفي بالتوزيع النجمي", "unitId": "g2-u2", "topicId": "t3"},
    {"title": "رسم جسم مع إظهار الضوء والظل", "unitId": "g3-u1", "topicId": "t1"},
    {"title": "رسم الظل الساقط على سطح", "unitId": "g2-u1", "topicId": "t5"},
    {"title": "تظليل الأشكال باستخدام تدرج القيم", "unitId": "g2-u1", "topicId": "t5"},
    {"title": "رسم موضوع من الطبيعة", "unitId": "g1-u1", "topicId": "t1"},
]

#: Supplemental Grade 3 topic drawings stored in ``tools/extra_drawings/``.
EXTRA_DRAWINGS: List[Dict[str, str]] = [
    {
        "file": "drawing-15.png",
        "title": "رسم مجسمات هندسية وفق قواعد المنظور ونقطتي التلاشي",
        "unitId": "g3-u1",
        "topicId": "t2",
    },
    {
        "file": "drawing-16.png",
        "title": "دراسة الخطوط البنائية ونسب جسم الإنسان",
        "unitId": "g3-u1",
        "topicId": "t3",
    },
    {
        "file": "drawing-17.png",
        "title": "رسم تكوين متوازن للطبيعة الصامتة وتظليله",
        "unitId": "g3-u1",
        "topicId": "t4",
    },
    {
        "file": "drawing-18.png",
        "title": "تحوير عنصر نباتي إلى وحدة زخرفية متناظرة",
        "unitId": "g3-u2",
        "topicId": "t1",
    },
    {
        "file": "drawing-19.png",
        "title": "بناء تكوين زخرفي بالخط الكوفي الهندسي على الشبكة",
        "unitId": "g3-u2",
        "topicId": "t2",
    },
    {
        "file": "drawing-20.png",
        "title": "تصميم ملصق إرشادي متوازن العناصر حول حماية البيئة",
        "unitId": "g3-u2",
        "topicId": "t3",
    },
]

ALL_DRAWINGS: List[Dict[str, str]] = DRAWINGS + EXTRA_DRAWINGS
