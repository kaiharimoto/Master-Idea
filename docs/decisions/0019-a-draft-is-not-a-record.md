# 0019 · An interview in progress is a draft, and drafts live outside the record

**Made:** while walking the whole workflow before shipping.
**Standing:** in force.

An interview is fifteen questions of the client's own words, and it is the
only stage where any of their work happens. It lived in a widget's state:
backgrounding the app on a phone lost all of it, with nothing on disk and no
way back. Now every answer goes straight to `draft.json`, and the arrival
screen picks up an interrupted interview where it stopped.

It is deliberately **not** a session.

A session is a record. Everything in `sessions/<id>/` has been through the
gate: the brief is confirmed, the unknowns are declared, the tier is decided,
and nothing may re-elicit an answer afterwards. A half-finished interview has
none of those properties, and putting one in the library would mean either a
session whose `interview/record.json` is a lie or a listing that shows
something you cannot open. So the draft sits beside `settings.json`, one at a
time, and is deleted the moment the gate closes over it — the record it became
is the copy that matters, and a draft that outlived it would be a second,
editable version of a constitution that is supposed to be frozen.

Answers stay editable until the gate closes, for the same reason from the
other side: nothing is frozen yet, so a typo in question three costs a
correction rather than the whole interview. After the gate nothing is
editable at all, which is what the sitting depends on.
