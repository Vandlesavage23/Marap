from rest_framework import serializers


class StoreVerifySerializer(serializers.Serializer):
    platform = serializers.ChoiceField(choices=["ios", "android"])
    signed_transaction = serializers.CharField(
        max_length=20000, required=False
    )  # iOS: StoreKit 2 JWS
    product_id = serializers.CharField(max_length=100, required=False)  # Android
    purchase_token = serializers.CharField(max_length=4096, required=False)  # Android

    def validate(self, attrs: dict) -> dict:
        if attrs["platform"] == "ios" and not attrs.get("signed_transaction"):
            raise serializers.ValidationError("signed_transaction is required for iOS.")
        if attrs["platform"] == "android" and not (
            attrs.get("product_id") and attrs.get("purchase_token")
        ):
            raise serializers.ValidationError(
                "product_id and purchase_token are required for Android."
            )
        return attrs
