# 0002 · The council's wire format is line-oriented, never JSON

**Made:** while designing `CouncilReplyParser`.
**Standing:** in force.

Master Prompt learned this twice. Its interview asks for a single fenced JSON
block, because a phone puts a copy button on a code block and one tap beats a
text selection. Its `mpstate` heartbeat stays line-oriented, because that block
is written *by* the model mid-run, where a truncated JSON object loses the
whole heartbeat and a truncated line grammar loses one field.

Every block in this tool is the second case. There is no human holding a phone
during a six-hour run, so nothing is gained by making a block convenient to
copy; and every block is written mid-run by a model that can be cut off at any
character. So the whole council grammar is line-oriented, and the parser keeps
a block whose closing `end` never arrived.

The one place a JSON block would be tempting is the `mi-pitch` export, because
the receiving end is code. It is line-oriented too, for the reason Master
Prompt's `HandoverSplitter` exists: a document that exceeds a paste ceiling is
cut without warning, and losing one field there is recoverable where losing the
object is not.
