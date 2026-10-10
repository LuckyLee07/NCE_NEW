import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest
import wave

SCRIPT = Path(__file__).resolve().parents[1] / "review_word_audio.py"
SPEC = importlib.util.spec_from_file_location("audio_review", SCRIPT)
review = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(review)


class WordAudioReviewTests(unittest.TestCase):
    def test_waveform_detects_padding_and_clipping(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "audio.wav"
            with wave.open(str(path), "wb") as audio:
                audio.setparams((1, 2, 24000, 0, "NONE", "not compressed"))
                samples = [0] * 2400 + [32767, -32768] * 2400 + [0] * 2400
                audio.writeframes(struct.pack("<" + "h" * len(samples), *samples))
            result = review.waveform(path)
            self.assertEqual(result["clipped_samples"], 4800)
            self.assertAlmostEqual(result["leading_silence_seconds"], 0.1)
            self.assertAlmostEqual(result["trailing_silence_seconds"], 0.1)
            self.assertAlmostEqual(result["active_seconds"], 0.2)

    def test_transcription_comparison_is_not_pronunciation_approval(self):
        self.assertEqual(review.normalized("St. Petersburg!"), "stpetersburg")
        self.assertNotEqual(review.normalized("Driving licence"), review.normalized("Driving license"))
        self.assertNotEqual(review.normalized("AT&T"), review.normalized("A T and T"))


if __name__ == "__main__":
    unittest.main()
