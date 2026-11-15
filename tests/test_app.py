import json, os, tempfile, unittest
from pathlib import Path
from unittest.mock import patch
from app import app

class AppContractTests(unittest.TestCase):
    def setUp(self):
        self.cwd = Path.cwd()
        self.temp = tempfile.TemporaryDirectory()
        os.chdir(self.temp.name)
        self.env = patch.dict(os.environ)
        self.env.start()
        os.environ.pop("S3_BUCKET", None)
        self.client = app.test_client()

    def tearDown(self):
        self.env.stop()
        os.chdir(self.cwd)
        self.temp.cleanup()

    def note(self, **extra):
        return self.client.post("/notes", data={"title":"Test title", "content":"Known content", **extra})

    def test_health(self):
        result = self.client.get("/health")
        self.assertEqual(result.status_code, 200)
        self.assertEqual(result.json["status"], "ok")

    def test_form_and_proxy_action(self):
        body = self.client.get("/").get_data(as_text=True)
        self.assertIn('action="notes"', body)
        self.assertIn('name="category"', body)

    def test_work_saved_exactly(self):
        result = self.note(category="work")
        self.assertEqual(result.status_code, 201)
        self.assertEqual(json.loads(Path(result.json["key"]).read_text()),
                         {"title":"Test title", "content":"Known content", "category":"work"})

    def test_missing_category_is_general(self):
        result = self.note()
        self.assertEqual(json.loads(Path(result.json["key"]).read_text())["category"], "general")

    def test_invalid_category_rejected(self):
        self.assertEqual(self.note(category="unsupported").status_code, 400)
        self.assertEqual(list(Path(".").glob("notes/*.json")), [])

    def test_empty_title_rejected(self):
        result = self.client.post("/notes", data={"title":" ", "content":"x"})
        self.assertEqual(result.status_code, 400)

    def test_limits(self):
        result = self.client.post("/notes", data={"title":"x"*101, "content":"x"})
        self.assertEqual(result.status_code, 400)

    def test_s3_contract_mocked_not_live(self):
        with patch.dict(os.environ, {"S3_BUCKET":"jblabs-mocked-only"}):
            with patch("boto3.client") as sdk:
                result = self.note(category="work")
                self.assertEqual(result.status_code, 201)
                args = sdk.return_value.put_object.call_args.kwargs
                self.assertEqual(args["Bucket"], "jblabs-mocked-only")
                self.assertEqual(args["Key"], result.json["key"])
                self.assertEqual(args["ContentType"], "application/json")
                self.assertEqual(json.loads(args["Body"])["category"], "work")
                self.assertEqual(list(Path(".").glob("notes/*.json")), [])

if __name__ == "__main__":
    unittest.main()
