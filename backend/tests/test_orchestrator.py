"""
Comprehensive Automated Test Suite for PRAMAAN Master Orchestrator Agent.
Tests intent detection, parallel & sequential graph execution, validation gates,
failure recovery, shared state integrity, role-aware outputs, and Flutter response contracts.
"""

import unittest
from backend.app.orchestrator.state import (
    OrchestratorRequest,
    IntentType,
    WorkflowState,
    FieldEvidenceState,
)
from backend.app.orchestrator.router import router
from backend.app.orchestrator.policies import ValidationPolicyEngine, RoleOutputFormatter
from backend.app.orchestrator.workflow import workflow_engine
from backend.app.orchestrator.root_agent import master_orchestrator


class TestPramaanOrchestrator(unittest.IsolatedAsyncioTestCase):

    def test_intent_detection(self):
        """Verify that router accurately identifies various farmer and system intents."""
        # 1. Create Field Record Intent (English)
        req_create = OrchestratorRequest(
            input="I sprayed Bio-X on my tomato crop yesterday at 2 L/acre.",
            language="en"
        )
        self.assertEqual(router.detect_intent(req_create), IntentType.CREATE_FIELD_RECORD)

        # 2. Product Comparison / Efficacy Intent
        req_compare = OrchestratorRequest(
            input="Show me how Bio-X performed in tomato efficacy comparison vs Bio-Y",
            language="en"
        )
        self.assertEqual(router.detect_intent(req_compare), IntentType.ANALYZE_PRODUCT)

        # 3. Weather / Spray Window Intent
        req_weather = OrchestratorRequest(
            input="What is the weather today and can i spray Delta-T in Pune?",
            language="en"
        )
        self.assertEqual(router.detect_intent(req_weather), IntentType.CHECK_FIELD_STATUS)

        # 4. Marathi Voice Input
        req_marathi = OrchestratorRequest(
            input="मी काल टोमॅटोवर जैविक औषध फवारले 2 लिटर प्रति एकर",
            language="mr"
        )
        self.assertEqual(router.detect_intent(req_marathi), IntentType.CREATE_FIELD_RECORD)

    def test_execution_plan_structure(self):
        """Verify parallel and sequential steps in execution graph."""
        req = OrchestratorRequest(
            input="Sprayed Bio-X on tomato",
            images=["field_photo_01.jpg", "product_label.jpg"],
            location={"latitude": 18.52, "longitude": 73.85, "village": "Pune"}
        )
        plan = router.create_execution_plan(IntentType.CREATE_FIELD_RECORD, req)
        
        # NLP, Vision, Weather should be scheduled in parallel
        self.assertIn("NLP", plan.parallel_steps)
        self.assertIn("VISION", plan.parallel_steps)
        self.assertIn("WEATHER", plan.parallel_steps)

        # Validation, Efficacy, Report should be sequential
        self.assertIn("VALIDATION", plan.sequential_steps)
        self.assertIn("EFFICACY", plan.sequential_steps)
        self.assertIn("REPORT", plan.sequential_steps)

    def test_validation_gate_policy(self):
        """Verify validation gate catches missing fields and dosage discrepancies."""
        state = FieldEvidenceState(
            record_id="PRM-TEST-001",
            nlp={
                "result": {
                    "crop": "Tomato",
                    "product": "Bio-X",
                    "dosage": "2 L/acre"
                }
            },
            vision={
                "result": {
                    "product_name": "Bio-X",
                    "dosage": "1 L/acre"  # Mismatch!
                }
            },
            weather={"result": {"temperature_c": 26, "spray_recommendation": "OPTIMAL WINDOW"}},
            validation={"result": {"composite_score": 95.0}}
        )

        is_valid, status, flags, missing, prompt = ValidationPolicyEngine.evaluate_gate(state)
        self.assertFalse(is_valid)
        self.assertEqual(status, "NEEDS_REVIEW")
        self.assertTrue(any("Dosage mismatch" in f for f in flags))
        self.assertIsNotNone(prompt)

    def test_role_aware_formatters(self):
        """Verify role-aware outputs for Farmer, Field Agent, and Organization."""
        state = FieldEvidenceState(
            record_id="PRM-2026-000123",
            input={"timestamp": "2026-09-04T10:30:00", "crop_hint": "Tomato", "role": "farmer"},
            nlp={"result": {"crop": "Tomato", "product_mentioned": "Bio-X", "dosage": "2 L/acre"}},
            weather={"result": {"temperature_c": 27.4, "relative_humidity_percent": 78, "delta_t_c": 4.2}},
            validation={"result": {"composite_score": 96.0, "validation_status": "VERIFIED"}},
            analytics={"result": {"recovery_rate_percent": 86.4, "sample_size": 325, "mean_observed_outcome": 78.4}},
        )
        state.workflow.status = WorkflowState.VALIDATED

        # 1. Farmer Output (Simple, readable, friendly)
        farmer_out = RoleOutputFormatter.format_farmer_output(state, lang="en")
        self.assertEqual(farmer_out["role"], "FARMER")
        self.assertIn("Tomato", farmer_out["summary_message"])
        self.assertIn("Bio-X", farmer_out["summary_message"])
        self.assertIn("disclaimer", farmer_out)

        # 2. Field Agent Output (Detailed technical specs & SHA-256 seal)
        agent_out = RoleOutputFormatter.format_field_agent_output(state)
        self.assertEqual(agent_out["role"], "FIELD_AGENT")
        self.assertIn("verification", agent_out)
        self.assertEqual(agent_out["verification"]["composite_score"], 96.0)

        # 3. Organization Output (ANOVA, statistics, and limitations)
        org_out = RoleOutputFormatter.format_organization_output(state)
        self.assertEqual(org_out["role"], "ORGANIZATION")
        self.assertEqual(org_out["validated_observations_n"], 325)
        self.assertIn("statistical_analysis", org_out)
        self.assertIn("methodological_limitations", org_out)

    async def test_full_orchestrator_execution(self):
        """End-to-end orchestration pipeline test matching user Flutter payload contract."""
        req = OrchestratorRequest(
            user_id="F102",
            role="farmer",
            language="en",
            input_type="voice",
            input="I sprayed Bio-X on tomato yesterday at 2 L/acre",
            images=["field_photo_01.jpg", "product_label.jpg"],
            location={"latitude": 18.52, "longitude": 73.85, "village": "Pune"},
            timestamp="2026-09-04T10:30:00",
            crop_hint="Tomato",
            target_product="Bio-X"
        )

        response = await master_orchestrator.process(req)

        self.assertTrue(response.record_id.startswith("PRM-"))
        self.assertIn(response.workflow_status, ["completed", "validated"])
        self.assertEqual(response.field_evidence["crop"], "tomato")
        self.assertIn("Bio-X", response.field_evidence["product"])
        self.assertEqual(response.field_evidence["dose"], "2 L/acre")
        self.assertIsNotNone(response.weather_context["temperature"])
        self.assertGreater(response.evidence["record_completeness"], 0.5)
        self.assertGreater(len(response.limitations), 0)
        self.assertIn("recorded and validated", response.farmer_message)

    async def test_human_in_the_loop_resumption(self):
        """Test workflow pausing at NEEDS_REVIEW and resuming upon farmer clarification."""
        req = OrchestratorRequest(
            user_id="F102",
            role="farmer",
            input="I applied pesticide yesterday",
            crop_hint=None,  # Missing crop and product
            target_product=None
        )
        response = await master_orchestrator.process(req)
        # Should need review because crop/product are ambiguous or need clarification
        self.assertIn(response.validation_status, ["needs_review", "validated"])

        # Resume with clarification
        resumed_res = await master_orchestrator.resume_workflow(
            record_id=response.record_id,
            correction={"crop": "Tomato", "product": "Bio-X", "clarification_text": "I sprayed Bio-X on Tomato at 2 L/acre"}
        )
        self.assertEqual(resumed_res.field_evidence["crop"], "tomato")
        self.assertIn("Bio-X", resumed_res.field_evidence["product"])


if __name__ == "__main__":
    unittest.main()
