const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();
const db = admin.firestore();

/**
 * Helper: Create nodemailer transporter from SMTP config
 */
function createTransporter(smtp) {
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

  return nodemailer.createTransport(transportConfig);
}

/**
 * Helper: Get SMTP config from Firestore
 */
async function getSmtpConfig() {
  const smtpDoc = await db.collection("settings").doc("smtp").get();
  if (!smtpDoc.exists) return null;
  const smtp = smtpDoc.data();
  if (!smtp.host || !smtp.username || !smtp.password) return null;
  return smtp;
}

/**
 * Helper: Update email queue doc and email log status
 */
async function updateStatus(queueRef, logId, status, errorMessage) {
  await queueRef.update({
    status: status,
    processed_at: admin.firestore.FieldValue.serverTimestamp(),
    error: errorMessage || null,
  });

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
      const smtp = await getSmtpConfig();
      if (!smtp) {
        console.error("SMTP configuration not found or incomplete");
        await updateStatus(snap.ref, emailData.log_id, "failed", "SMTP configuration not found or incomplete");
        return;
      }

      const transporter = createTransporter(smtp);

      const mailOptions = {
        from: `"${smtp.from_name || "Lead Management"}" <${smtp.from_email || smtp.username}>`,
        to: emailData.to_email,
        subject: emailData.subject,
        html: `<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          ${emailData.body.replace(/\n/g, "<br>")}
          <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 20px 0;">
          <p style="color: #757575; font-size: 11px;">Sent from Lead Management System</p>
        </div>`,
        text: emailData.body,
      };

      const info = await transporter.sendMail(mailOptions);
      console.log(`Email sent to ${emailData.to_email}. MessageId: ${info.messageId}`);

      await updateStatus(snap.ref, emailData.log_id, "sent", null);
    } catch (error) {
      console.error(`Error sending email to ${emailData.to_email}:`, error.message);
      await updateStatus(snap.ref, emailData.log_id, "failed", error.message);
    }
  });

/**
 * Callable function to test SMTP connection.
 * Sends a test email to the configured from_email address.
 */
exports.testSmtpConnection = functions.https.onCall(async (data, context) => {
  try {
    const smtp = await getSmtpConfig();
    if (!smtp) {
      return { success: false, error: "SMTP configuration not found or incomplete. Please save your SMTP settings first." };
    }

    const transporter = createTransporter(smtp);

    // Send a test email to the from_email address
    const testEmail = smtp.from_email || smtp.username;
    const mailOptions = {
      from: `"${smtp.from_name || "LMS Test"}" <${testEmail}>`,
      to: testEmail,
      subject: "LMS - SMTP Test Connection",
      html: `<div style="font-family: Arial, sans-serif; max-width: 500px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #1565C0;">SMTP Test Successful!</h2>
        <p>This is a test email from the <strong>Lead Management System</strong>.</p>
        <p>If you received this, your SMTP settings are configured correctly.</p>
        <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 20px 0;">
        <p style="color: #757575; font-size: 12px;">Timestamp: ${new Date().toISOString()}</p>
      </div>`,
      text: `SMTP Test Successful!\n\nThis is a test email from the Lead Management System.\nIf you received this, your SMTP settings are configured correctly.\n\nTimestamp: ${new Date().toISOString()}`,
    };

    await transporter.sendMail(mailOptions);

    return { success: true, message: `Test email sent to ${testEmail}` };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

/**
 * Callable function to send an email immediately.
 * Used by the Flutter web app since it can't use dart:io SMTP directly.
 */
exports.sendEmailNow = functions.https.onCall(async (data, context) => {
  try {
    const { toEmail, toName, subject, body, logId } = data;

    if (!toEmail || !subject || !body) {
      return { success: false, error: "Missing required fields: toEmail, subject, body" };
    }

    const smtp = await getSmtpConfig();
    if (!smtp) {
      return { success: false, error: "SMTP configuration not found or incomplete" };
    }

    const transporter = createTransporter(smtp);

    const mailOptions = {
      from: `"${smtp.from_name || "Lead Management"}" <${smtp.from_email || smtp.username}>`,
      to: toEmail,
      subject: subject,
      html: `<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        ${body.replace(/\n/g, "<br>")}
        <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 20px 0;">
        <p style="color: #757575; font-size: 11px;">Sent from Lead Management System</p>
      </div>`,
      text: body,
    };

    const info = await transporter.sendMail(mailOptions);
    console.log(`Email sent to ${toEmail}. MessageId: ${info.messageId}`);

    // Update email log if provided
    if (logId) {
      try {
        await db.collection("email_logs").doc(logId).update({
          status: "sent",
          error_message: null,
        });
      } catch (e) {
        console.error(`Failed to update email_log ${logId}:`, e.message);
      }
    }

    return { success: true, message: `Email sent to ${toEmail}` };
  } catch (error) {
    console.error(`Error sending email:`, error.message);
    return { success: false, error: error.message };
  }
});

/**
 * Callable function to process pending emails in the queue.
 * Used when the automatic trigger didn't fire or needs retry.
 */
exports.processEmailQueue = functions.https.onCall(async (data, context) => {
  try {
    const smtp = await getSmtpConfig();
    if (!smtp) {
      return { success: false, error: "SMTP configuration not found", processed: 0 };
    }

    const transporter = createTransporter(smtp);

    const snapshot = await db.collection("email_queue")
      .where("status", "==", "pending")
      .limit(20)
      .get();

    if (snapshot.empty) {
      return { success: true, message: "No pending emails in queue", processed: 0 };
    }

    let sent = 0;
    let failed = 0;

    for (const doc of snapshot.docs) {
      const emailData = doc.data();
      try {
        const mailOptions = {
          from: `"${smtp.from_name || "Lead Management"}" <${smtp.from_email || smtp.username}>`,
          to: emailData.to_email,
          subject: emailData.subject,
          html: `<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            ${emailData.body.replace(/\n/g, "<br>")}
            <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 20px 0;">
            <p style="color: #757575; font-size: 11px;">Sent from Lead Management System</p>
          </div>`,
          text: emailData.body,
        };

        await transporter.sendMail(mailOptions);
        await updateStatus(doc.ref, emailData.log_id, "sent", null);
        sent++;
      } catch (error) {
        await updateStatus(doc.ref, emailData.log_id, "failed", error.message);
        failed++;
      }
    }

    return {
      success: true,
      message: `Processed ${sent + failed} emails: ${sent} sent, ${failed} failed`,
      processed: sent,
      failed: failed,
    };
  } catch (error) {
    return { success: false, error: error.message, processed: 0 };
  }
});
