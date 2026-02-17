const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();
const db = admin.firestore();

/**
 * Cloud Function triggered when a new document is created in email_queue.
 * Reads SMTP config from Firestore, sends the email, and updates the log.
 */
exports.sendQueuedEmail = functions.firestore
  .document("email_queue/{docId}")
  .onCreate(async (snap, context) => {
    const emailData = snap.data();
    const docId = context.params.docId;

    console.log(`Processing email queue item: ${docId}`);

    try {
      // 1. Get SMTP configuration from Firestore
      const smtpDoc = await db.collection("settings").doc("smtp").get();
      if (!smtpDoc.exists) {
        console.error("SMTP configuration not found in settings/smtp");
        await updateStatus(snap.ref, emailData.log_id, "failed", "SMTP configuration not found");
        return;
      }

      const smtp = smtpDoc.data();

      // Validate required SMTP fields
      if (!smtp.host || !smtp.username || !smtp.password) {
        console.error("SMTP configuration incomplete");
        await updateStatus(snap.ref, emailData.log_id, "failed", "SMTP configuration incomplete");
        return;
      }

      // 2. Create SMTP transporter
      const transportConfig = {
        host: smtp.host,
        port: parseInt(smtp.port) || 587,
        secure: smtp.use_ssl === true,
        auth: {
          user: smtp.username,
          pass: smtp.password,
        },
      };

      // Add TLS option if enabled
      if (smtp.use_tls === true && !smtp.use_ssl) {
        transportConfig.requireTLS = true;
      }

      const transporter = nodemailer.createTransport(transportConfig);

      // 3. Build mail options
      const mailOptions = {
        from: `"${smtp.from_name || "Lead Management"}" <${smtp.from_email || smtp.username}>`,
        to: emailData.to_email,
        subject: emailData.subject,
        html: emailData.body.replace(/\n/g, "<br>"),
        text: emailData.body,
      };

      // 4. Send the email
      const info = await transporter.sendMail(mailOptions);
      console.log(`Email sent successfully to ${emailData.to_email}. MessageId: ${info.messageId}`);

      // 5. Update status to sent
      await updateStatus(snap.ref, emailData.log_id, "sent", null);

    } catch (error) {
      console.error(`Error sending email to ${emailData.to_email}:`, error.message);
      await updateStatus(snap.ref, emailData.log_id, "failed", error.message);
    }
  });

/**
 * Helper: Update email queue doc and email log status
 */
async function updateStatus(queueRef, logId, status, errorMessage) {
  // Update queue document
  await queueRef.update({
    status: status,
    processed_at: admin.firestore.FieldValue.serverTimestamp(),
    error: errorMessage || null,
  });

  // Update the email log if we have a log_id
  if (logId) {
    try {
      await db.collection("email_logs").doc(logId).update({
        status: status,
        error_message: errorMessage || null,
      });
    } catch (e) {
      console.error(`Failed to update email_log ${logId}:`, e.message);
    }
  }
}

/**
 * HTTP callable function to test SMTP connection
 * Can be called from the Flutter app to validate SMTP settings
 */
exports.testSmtpConnection = functions.https.onCall(async (data, context) => {
  try {
    const smtpDoc = await db.collection("settings").doc("smtp").get();
    if (!smtpDoc.exists) {
      return { success: false, error: "SMTP configuration not found" };
    }

    const smtp = smtpDoc.data();
    const transportConfig = {
      host: smtp.host,
      port: parseInt(smtp.port) || 587,
      secure: smtp.use_ssl === true,
      auth: {
        user: smtp.username,
        pass: smtp.password,
      },
    };

    if (smtp.use_tls === true && !smtp.use_ssl) {
      transportConfig.requireTLS = true;
    }

    const transporter = nodemailer.createTransport(transportConfig);
    await transporter.verify();

    return { success: true, message: "SMTP connection verified successfully" };
  } catch (error) {
    return { success: false, error: error.message };
  }
});
